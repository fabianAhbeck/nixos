# Hyprland session: compositor, greeter, portals, audio, graphics, fonts.
# The per-user Hyprland *configuration* lives in home/hyprland.nix.
{
  config,
  lib,
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

  # Login manager. tuigreet is a text greeter -- it starts in ~0.2s and does
  # not drag in a second GTK stack just to type a password.
  services.greetd = {
    enable = true;
    # Sets up the tty handling (Type=idle, TTYReset, output to tty1) so the
    # greeter doesn't fight the boot log for the console. Don't hand-roll this
    # in systemd.services.greetd -- it collides with the module.
    useTextGreeter = true;
    # start-hyprland is Hyprland's launcher: it restarts the compositor after a
    # crash instead of dropping to the greeter, and Hyprland warns at startup
    # without it. No --remember-session: there is only one session, and a
    # remembered one ("Hyprland") would override --cmd.
    #
    # Styled to match the desktop: the named colours below resolve through the
    # Catppuccin Mocha console palette (console.colors in hosts/zenbook), so
    # blue is the same #89b4fa as Waybar and the window borders. Preview a
    # change without logging out with `tuigreet --mock <same flags>` in kitty.
    settings.default_session = {
      command = lib.escapeShellArgs [
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--time-format"
        "%A %d %B  ·  %H:%M"
        "--battery"
        "--remember"
        "--asterisks"
        "--asterisks-char"
        "•"
        "--title"
        "--custom-title"
        " zenbook "
        "--greeting"
        "Welcome back"
        "--width"
        "52"
        "--window-padding"
        "2"
        "--container-padding"
        "2"
        "--prompt-padding"
        "1"
        "--theme"
        "border=blue;title=blue;text=gray;greet=magenta;prompt=blue;input=gray;time=magenta;action=blue;button=magenta;container=black"
        "--cmd"
        "${config.programs.hyprland.package}/bin/start-hyprland"
      ];
      user = "greeter";
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
  # Graphics -- the GPU drivers themselves are per machine (hosts/<name>/)
  ###########################################################################

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Steam / Wine
  };

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

  # Redistributable and unfree firmware: Wi-Fi, GPUs, and audio DSPs (the
  # zenbook's Tiger Lake SST codec needs SOF firmware to make any sound).
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
  security.pam.services.greetd.enableGnomeKeyring = true;

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
