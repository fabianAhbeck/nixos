{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    ../../modules/nix.nix
    ../../modules/desktop.nix
    ../../modules/dev.nix
    ../../modules/apps.nix
    ../../modules/virtualisation.nix
  ];

  ###########################################################################
  # Boot
  ###########################################################################

  boot.loader.systemd-boot = {
    enable = true;
    # /boot is 1G; each generation costs a kernel + initrd (~150MB).
    configurationLimit = 10;
    editor = false; # don't let anyone with the laptop append init=/bin/sh
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd in the initrd: nicer LUKS passphrase prompt, plymouth handoff,
  # and it is what TPM2 unlock needs if you add it later.
  boot.initrd.systemd.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.plymouth.enable = true;
  boot.kernelParams = [
    "quiet"
    "splash"
    # Tiger Lake: enable GuC/HuC firmware loading for media offload.
    "i915.enable_guc=3"

    # Hibernation: physical offset of /swap/swapfile inside cryptroot, from
    #   sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
    # Re-run and update this if the swapfile is ever recreated.
    "resume_offset=533760"
  ];
  boot.resumeDevice = "/dev/mapper/cryptroot";

  ###########################################################################
  # Networking
  ###########################################################################

  networking.hostName = "zenbook";
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd"; # noticeably better roaming than wpa_supplicant on AX201
    plugins = [ pkgs.networkmanager-openvpn ];

    # Home VPN: whenever a network comes up, connect `home-vpn` unless we're
    # on the home Wi-Fi, where it's disconnected instead. The connection
    # itself (with its keys and password) is imported into NetworkManager,
    # not kept in this repo; see "Home VPN" in README.md.
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

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  ###########################################################################
  # Locale -- mirrors the current Ubuntu setup: Swedish keyboard, English UI,
  # Swedish formats for dates/currency/paper size.
  ###########################################################################

  time.timeZone = "Europe/Stockholm";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_NAME = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_TELEPHONE = "sv_SE.UTF-8";
    LC_TIME = "sv_SE.UTF-8";
  };

  console.keyMap = "sv-latin1";
  # Catppuccin Mocha for the text console, i.e. the greeter and any tty.
  # Order: black red green yellow blue magenta cyan white, then the bright
  # variants. black/white double as the console background/foreground.
  console.colors = [
    "1e1e2e"
    "f38ba8"
    "a6e3a1"
    "f9e2af"
    "89b4fa"
    "cba6f7"
    "94e2d5"
    "cdd6f4"
    "585b70"
    "f38ba8"
    "a6e3a1"
    "f9e2af"
    "b4befe"
    "f5c2e7"
    "89dceb"
    "a6adc8"
  ];
  # Terminus 12x24: the default 8x16 font is tiny on a 1080p panel.
  console.font = "ter-v24n";
  console.packages = [ pkgs.terminus_font ];
  # Wayland compositors read this; see also the `input` block in home/hyprland.nix.
  services.xserver.xkb = {
    layout = "se";
    variant = "";
  };

  ###########################################################################
  # Users
  ###########################################################################

  users.users.fabian = {
    isNormalUser = true;
    description = "Fabian Åhbeck";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "libvirtd"
      "docker"
      "dialout" # serial consoles / flashing boards
    ];
    shell = pkgs.zsh;
    # Set with `passwd` on first boot, or seed a hashed password here:
    # hashedPassword = "$6$...";
  };

  # Ask for a password on sudo, but don't re-ask constantly in a shell session.
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
  '';

  ###########################################################################
  # Power / firmware -- laptop bits
  ###########################################################################

  # ASUS charge threshold: keeping the cell at 80% roughly doubles its
  # calendar life if the machine spends most of its time docked.
  hardware.asus.battery.chargeUpto = 80;

  services.thermald.enable = true;
  services.fwupd.enable = true; # ASUS ships UX425EA firmware to LVFS

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

  # Lid close and the power button both suspend; hibernate is opt-in via the
  # power menu once resume_offset is set.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "suspend";
  };

  ###########################################################################
  # Home Manager
  ###########################################################################

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.fabian = import ../../home/fabian.nix;
    # Rename rather than fail when HM wants to take over a file that already exists.
    backupFileExtension = "hm-bak";
  };

  ###########################################################################
  # The version of NixOS this machine was first installed with. Do NOT bump it
  # on upgrade -- it pins stateful defaults (database versions and the like).
  ###########################################################################
  system.stateVersion = "26.05";
}
