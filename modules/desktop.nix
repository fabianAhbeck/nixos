# Hyprland session: compositor, greeter, portals, audio, graphics, fonts.
# The per-user Hyprland *configuration* lives in home/hyprland.nix.
{
  config,
  pkgs,
  ...
}:
{
  ###########################################################################
  # Compositor
  ###########################################################################

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # UWSM is the other way to launch Hyprland; we let Home Manager own the
    # systemd session target instead (see systemd.enable in home/hyprland.nix).
    withUWSM = false;
  };

  # Login manager: ly, a text greeter on tty1 with an animated background.
  # colormix slowly blends Catppuccin blue and mauve into the base colour
  # behind a login box styled like the rest of the desktop. Colours are
  # 0xSSRRGGBB, SS being styling (01 = bold). The Hyprland session entry
  # already launches start-hyprland. Logs: /var/log/ly.log.
  services.displayManager = {
    defaultSession = "hyprland";
    ly = {
      enable = true;
      x11Support = false;
      settings = {
        animation = "colormix";
        colormix_col1 = "0x0089B4FA"; # blue
        colormix_col2 = "0x00CBA6F7"; # mauve
        colormix_col3 = "0x001E1E2E"; # base
        animation_frame_delay = 33; # ~30 fps; the default 5 ms is 200 fps
        # Freeze the animation after 10 min so an idle greeter doesn't burn
        # battery.
        animation_timeout_sec = 600;

        bg = "0x001E1E2E";
        fg = "0x00CDD6F4";
        border_fg = "0x0089B4FA";
        error_fg = "0x01F38BA8";
        box_title = "zenbook";
        clock = "%A %d %B  ·  %H:%M";
        battery_id = "BAT0";
        asterisk = "0x2022"; # •
        default_input = "password"; # the username is remembered

        sleep_cmd = "/run/current-system/systemd/bin/systemctl suspend";
        hibernate_cmd = "/run/current-system/systemd/bin/systemctl hibernate";
      };
    };
  };

  # hyprlock authenticates against PAM; it needs its own service entry.
  security.pam.services.hyprlock = { };

  # Let the compositor request realtime priority.
  security.rtkit.enable = true;

  ###########################################################################
  # Portals -- file pickers, screen sharing, opening links from sandboxed apps
  ###########################################################################

  xdg.portal = {
    enable = true;
    # xdg-desktop-portal-hyprland is added automatically by programs.hyprland.
    # GTK provides the file chooser and Settings (theme) interfaces.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  ###########################################################################
  # Graphics -- Tiger Lake Iris Xe
  ###########################################################################

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / Wine
    extraPackages = with pkgs; [
      intel-media-driver # iHD VA-API driver, the right one for Gen11+
      vpl-gpu-rt # QSV / oneVPL runtime for hardware encode
      intel-compute-runtime # OpenCL
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  ###########################################################################
  # Audio
  ###########################################################################

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # The UX425EA's Tiger Lake SST codec needs the SOF firmware to produce sound.
  hardware.enableAllFirmware = true;

  ###########################################################################
  # Bluetooth
  ###########################################################################

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # save the idle drain; toggle from the Waybar applet
    settings.General.Experimental = true; # battery level reporting for headsets
  };
  services.blueman.enable = true;

  ###########################################################################
  # Secrets, keyring, peripherals
  ###########################################################################

  services.gnome.gnome-keyring.enable = true; # VS Code, Thunderbird, nm-applet

  # brightnessctl ships the udev rules that let members of `video` write to
  # the backlight without root.
  services.udev.packages = [ pkgs.brightnessctl ];

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      hplip
    ];
  };
  # Network printer and .local discovery.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Auto-mount USB sticks from the file manager.
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  ###########################################################################
  # Fonts
  ###########################################################################

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      inter
      jetbrains-mono
      nerd-fonts.jetbrains-mono # glyphs for Waybar / starship / neovim
      nerd-fonts.symbols-only
    ];
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" ];
      sansSerif = [ "Inter" ];
      monospace = [ "JetBrainsMono Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  ###########################################################################
  # Session packages
  ###########################################################################

  environment.systemPackages = with pkgs; [
    # Wayland plumbing
    wl-clipboard
    cliphist
    grim
    slurp
    swappy # annotate a screenshot before sending it
    wf-recorder
    hyprpicker
    hyprpolkitagent # the polkit prompt (mounting disks, virt-manager, fwupd)
    brightnessctl
    playerctl
    pavucontrol
    wireplumber

    # A file manager and an image/pdf viewer, so "open containing folder" works
    nautilus
    loupe
    evince
  ];

  # Polkit agent has to be running for any privileged GUI prompt to appear.
  security.polkit.enable = true;

  # Let a pkexec authorization stick for a few minutes, like sudo's
  # timestamp. polkit keys it to the calling process, so `rebuild-bg`'s
  # single nh run (profile, activate, bootloader: three pkexec calls) asks
  # for the password once, and other programs still ask for their own.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.policykit.exec" && subject.isInGroup("wheel")) {
        return polkit.Result.AUTH_ADMIN_KEEP;
      }
    });
  '';
}
