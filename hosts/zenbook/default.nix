# ASUS ZenBook UX425EA: i7-1165G7 (Tiger Lake), Iris Xe, 1080p panel.
# Everything shared with other machines comes from ../../modules (added by
# mkHost in flake.nix); this file is only what is specific to this laptop.
{ inputs, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    # No nixos-hardware profile exists for the UX425EA specifically, so we
    # compose the generic ones. asus-battery gives us the charge threshold.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    inputs.nixos-hardware.nixosModules.asus-battery
  ];

  networking.hostName = "zenbook";

  my = {
    monitors = [
      # Scale 1.25: everything 25% larger at full resolution (a 1536x864
      # logical desktop). SUPER + plus/minus changes it until the next reload.
      {
        output = "eDP-1";
        mode = "1920x1080@60";
        position = "0x0";
        scale = 1.25;
      }
    ];
    backlight = "intel_backlight";
    laptop = true;
  };

  # 8 threads on the i7-1165G7; leave two free during big rebuilds.
  nix.settings.cores = 6;

  ###########################################################################
  # Graphics -- Tiger Lake Iris Xe
  ###########################################################################

  # The drivers themselves (intel-media-driver for VA-API, vpl-gpu-rt for
  # QSV encode, intel-compute-runtime for OpenCL) come from nixos-hardware's
  # common-cpu-intel profile above. It also installs the legacy i965 driver,
  # so pin VA-API to iHD, the right one for Gen11+.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  ###########################################################################
  # Boot: GPU firmware and hibernation
  ###########################################################################

  boot.kernelParams = [
    # Tiger Lake: enable GuC/HuC firmware loading for media offload.
    "i915.enable_guc=3"

    # Hibernation: physical offset of /swap/swapfile inside cryptroot, from
    #   sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
    # Re-run and update this if the swapfile is ever recreated.
    "resume_offset=533760"
  ];
  boot.resumeDevice = "/dev/mapper/cryptroot";

  ###########################################################################
  # Bluetooth audio
  ###########################################################################

  # The AX201's Bluetooth turns headset-mode audio with the mSBC codec into
  # pure static (tested with Bose QC Ultra 2 earbuds: mSBC static, CVSD
  # clean). Headset mode is what apps like Discord switch to for the
  # earbuds' mic, so offer only CVSD there: narrowband but clear. Music
  # stays on A2DP (AAC) and is unaffected.
  services.pipewire.wireplumber.extraConfig."10-disable-msbc" = {
    "monitor.bluez.properties"."bluez5.enable-msbc" = false;
  };

  ###########################################################################
  # Home VPN
  ###########################################################################

  networking.networkmanager = {
    plugins = [ pkgs.networkmanager-openvpn ];

    # Whenever a network comes up, connect `home-vpn` unless we're on the
    # home Wi-Fi, where it's disconnected instead. The connection itself
    # (with its keys and password) is imported into NetworkManager, not kept
    # in this repo; see "Home VPN" in README.md.
    dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "home-vpn" ''
          vpn="home-vpn"
          home_ssid="Calaverea Cafe"
          nmcli=${pkgs.networkmanager}/bin/nmcli

          case "$2" in up | down | connectivity-change) ;; *) exit 0 ;; esac
          [ "$CONNECTION_ID" = "$vpn" ] && exit 0 # the VPN's own events
          $nmcli -g NAME connection show | grep -qxF "$vpn" || exit 0 # not imported

          active=$($nmcli -g UUID,TYPE,NAME connection show --active)
          at_home=false online=false vpn_up=false
          while IFS=: read -r uuid type name; do
            case "$type" in
              802-11-wireless)
                online=true
                [ "$($nmcli -g 802-11-wireless.ssid connection show "$uuid")" = "$home_ssid" ] && at_home=true
                ;;
              802-3-ethernet) online=true ;;
              vpn) [ "$name" = "$vpn" ] && vpn_up=true ;;
            esac
          done <<< "$active"

          if $at_home; then
            $vpn_up && $nmcli connection down "$vpn"
          elif $online && ! $vpn_up; then
            # Backgrounded: dispatcher scripts have a timeout, and bringing a
            # VPN up can take a while.
            $nmcli connection up "$vpn" >/dev/null 2>&1 &
          fi
          exit 0
        '';
      }
    ];
  };

  ###########################################################################
  # Power / firmware -- laptop bits
  ###########################################################################

  # ASUS charge threshold: keeping the cell at 80% roughly doubles its
  # calendar life if the machine spends most of its time docked.
  hardware.asus.battery.chargeUpto = 80;

  services.thermald.enable = true;

  # TLP rather than power-profiles-daemon: no GNOME here to drive PPD's
  # profile switching, and TLP's defaults are better on battery.
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      # No turbo boost on battery: short bursts run a little slower, but the
      # CPU stays cooler and draws far less.
      CPU_BOOST_ON_BAT = 0;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;
      # The charge threshold is handled by hardware.asus.battery above; don't
      # let TLP fight it.
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
    };
  };

  # Sustained CPU power limit 20 W instead of the firmware's 25 W (MSR) /
  # 28 W (MMIO): gaming on AC reached the mid 90s °C with the fan already
  # at its maximum profile. Bursts keep the firmware's 42 W. The limit
  # covers the whole package, Iris Xe GPU included. Both RAPL interfaces
  # are set, since the lower one wins; again after resume, which can reset
  # them.
  systemd.services.cpu-power-limit = {
    description = "Lower the sustained CPU power limit";
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    after = [ "post-resume.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for zone in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
        echo 20000000 > "$zone/constraint_0_power_limit_uw"
      done
    '';
  };

  # Temperature log: every 5 s, the CPU package temperature, package power
  # and whether we're on AC, one CSV per day in /var/log/temp-log (kept 30
  # days). Root because the RAPL energy counter is root-only. `temps`
  # summarises it per day.
  systemd.services.temp-log = {
    description = "Log CPU temperature and power";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Restart = "always";
    script = ''
      dir=/var/log/temp-log
      for z in /sys/class/thermal/thermal_zone*; do
        [ "$(cat "$z/type")" = x86_pkg_temp ] && temp=$z/temp
      done
      energy=/sys/class/powercap/intel-rapl:0/energy_uj
      range=$(cat /sys/class/powercap/intel-rapl:0/max_energy_range_uj)
      last=$(cat "$energy") last_t=$(date +%s%N)
      while sleep 5; do
        now=$(cat "$energy") now_t=$(date +%s%N)
        # The counter wraps; after resume the gap is long, which only
        # averages the power down, never up.
        d=$(( (now - last + range) % range ))
        watts=$(( d * 10000 / (now_t - last_t) ))  # µJ/ns -> tenths of W
        last=$now last_t=$now_t
        ac=1; [ "$(cat /sys/class/power_supply/BAT0/status)" = Discharging ] && ac=0
        f=$dir/$(date +%F).csv
        [ -e "$f" ] || echo time,temp_c,watts,ac > "$f"
        printf '%s,%d,%d.%d,%d\n' "$(date +%T)" $(( $(cat "$temp") / 1000 )) \
          $((watts / 10)) $((watts % 10)) $ac >> "$f"
      done
    '';
  };
  systemd.tmpfiles.rules = [ "d /var/log/temp-log 0755 root root 30d" ];

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "temps";
      runtimeInputs = [ pkgs.gawk ];
      text = ''
        # Per-day summary of /var/log/temp-log: `temps` for the last 7
        # days, `temps 30` for more.
        days=''${1:-7}
        printf '%-10s  %5s  %8s  %5s  %5s  %5s  %6s\n' \
          day peak "at" ">=85" ">=90" ">=95" "max W"
        shopt -s nullglob
        files=(/var/log/temp-log/*.csv)
        start=$(( ''${#files[@]} > days ? ''${#files[@]} - days : 0 ))
        for f in "''${files[@]:start}"; do
          awk -F, -v day="$(basename "$f" .csv)" '
            NR == 1 { next }
            $2 > peak { peak = $2; at = $1 }
            $2 >= 85 { h85++ } $2 >= 90 { h90++ } $2 >= 95 { h95++ }
            $3 > maxw { maxw = $3 }
            # samples are 5 s apart; show minutes
            END { printf "%-10s  %4d°  %8s  %4dm  %4dm  %4dm  %6.1f\n",
                  day, peak, at, h85/12, h90/12, h95/12, maxw }' "$f"
        done
      '';
    })
  ];

  # Sleep. The firmware defaults to s2idle ("modern standby"), which keeps
  # much of a Tiger Lake system half awake and drains several % an hour;
  # deep (S3, suspend-to-RAM) powers almost everything down. On battery, lid
  # and power button suspend and then hibernate after 2 hours, so a laptop
  # left closed overnight uses nothing. On AC, the lid just suspends.
  systemd.sleep.settings.Sleep = {
    MemorySleepMode = "deep";
    HibernateDelaySec = "2h";
  };
  # Battery running out: UPower hibernates at 3% instead of letting the
  # laptop die (home/battery.nix warns at 15% and 5% first).
  services.upower = {
    enable = true;
    percentageLow = 15;
    percentageCritical = 5;
    percentageAction = 3;
    criticalPowerAction = "Hibernate";
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend-then-hibernate";
  };

  ###########################################################################
  # The version of NixOS this machine was first installed with. Do NOT bump it
  # on upgrade -- it pins stateful defaults (database versions and the like).
  ###########################################################################
  system.stateVersion = "26.05";
}
