# Basics every machine gets: boot, networking, locale and console, the user,
# sudo, firmware updates, and the Home Manager wiring. Hardware, power and
# anything else specific to one machine lives in hosts/<name>/.
{ inputs, pkgs, ... }:
{
  ###########################################################################
  # Boot
  ###########################################################################

  boot.loader.systemd-boot = {
    enable = true;
    # /boot is 1G (see hosts/*/disko.nix); each generation costs a kernel +
    # initrd (~150MB).
    configurationLimit = 10;
    editor = false; # don't let anyone at the machine append init=/bin/sh
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd in the initrd: nicer LUKS passphrase prompt, plymouth handoff,
  # and it is what TPM2 unlock needs if you add it later.
  boot.initrd.systemd.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # plymouth adds `splash` to the kernel command line itself.
  boot.plymouth.enable = true;
  boot.kernelParams = [ "quiet" ];

  ###########################################################################
  # Networking
  ###########################################################################

  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd"; # noticeably better roaming than wpa_supplicant
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  ###########################################################################
  # Locale -- Swedish keyboard, English UI, Swedish formats for
  # dates/currency/paper size.
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
  # Wayland compositors read this; see also the `input` block in home/hyprland.lua.
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

  services.fwupd.enable = true; # firmware updates from LVFS

  ###########################################################################
  # Home Manager
  ###########################################################################

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.fabian = import ../home/fabian.nix;
    # Rename rather than fail when HM wants to take over a file that already exists.
    backupFileExtension = "hm-bak";
  };
}
