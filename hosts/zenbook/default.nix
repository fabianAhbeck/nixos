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
    cpuTempSensor = "/sys/devices/platform/coretemp.0/hwmon"; # Tiger Lake package sensor
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
      # The charge threshold is handled by hardware.asus.battery above; don't
      # let TLP fight it.
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
    };
  };

  # Lid close and the power button both suspend; hibernate is in the power
  # menu (SUPER+SHIFT+Q).
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
  };

  ###########################################################################
  # The version of NixOS this machine was first installed with. Do NOT bump it
  # on upgrade -- it pins stateful defaults (database versions and the like).
  ###########################################################################
  system.stateVersion = "26.05";
}
