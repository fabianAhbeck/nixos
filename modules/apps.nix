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

  # Iris Xe is modest, but it is what the machine has; 32-bit graphics support
  # is set in modules/desktop.nix (hardware.graphics.enable32Bit).

  environment.systemPackages = with pkgs; [
    # Communication
    discord

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
    mangohud
    protonup-qt
  ];

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  users.users.fabian.extraGroups = [ "wireshark" ];
}
