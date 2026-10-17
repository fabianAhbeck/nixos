# Desktop applications and gaming.
{ pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    # Wayland-native rendering and hardware video decode via iHD.
    preferences = {
      "media.ffmpeg.vaapi.enabled" = true;
      "gfx.webrender.all" = true;
    };
  };

  programs.thunderbird.enable = true;

  ###########################################################################
  # Steam
  ###########################################################################

  programs.steam = {
    enable = true;
    # gamescope gives Proton titles a sane scaling/compositing target under a
    # tiling WM, where fullscreen handling is otherwise hit and miss.
    gamescopeSession.enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
    protontricks.enable = true;
  };
  programs.gamemode.enable = true;

  # Logitech G29 wheel under Proton. Proton's SDL layer maps the wheel as a
  # gamepad and the steering axis reads half-range. The fix is to hand the
  # game the raw HID device instead, with these launch options in Steam:
  #
  #   PROTON_ENABLE_HIDRAW=0x046d/0xc24f %command%
  #
  # which needs the logged-in user to be able to open /dev/hidraw*. `uaccess`
  # grants that to whoever owns the seat, rather than MODE=0666 to everyone;
  # the file must sort before 73-seat-late.rules for the tag to take effect,
  # hence a numbered file via udev.packages rather than services.udev.extraRules.
  # c24f is the G29 in PS3 mode (check `lsusb`); it reports a different ID
  # in PS4 mode.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "logitech-g29-udev-rules";
      destination = "/etc/udev/rules.d/70-logitech-g29.rules";
      text = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c24f", TAG+="uaccess"
      '';
    })
  ];

  # Iris Xe is modest, but it is what the machine has; 32-bit graphics support
  # is set in modules/desktop.nix (hardware.graphics.enable32Bit).

  environment.systemPackages = with pkgs; [
    # Communication
    discord
    slack

    # Media
    vlc
    mpv

    # Office
    libreoffice
    hunspell
    hunspellDicts.en_US
    hunspellDicts.sv_SE

    # Dev-adjacent GUI
    postman
    wireshark

    # Utilities
    rpi-imager
    transmission_4-gtk
    gnome-disk-utility
    baobab # disk usage
    gnome-calculator
    seahorse # keyring UI

    # Gaming
    protonup-qt
    godot # game engine and editor
  ];

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  users.users.fabian.extraGroups = [ "wireshark" ];
}
