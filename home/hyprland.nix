# Hyprland compositor configuration.
#
# Keyboard layout is Swedish, matching the current install. SUPER is the mod
# key. Workspaces 1-10 on SUPER+<n>, move window with SUPER+SHIFT+<n>.
{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;

    # Binds the session to systemd's graphical-session.target, which is what
    # Waybar / mako / hypridle key off. This is why we don't need UWSM.
    systemd = {
      enable = true;
      variables = [ "--all" ];
    };

    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "wofi --show drun";
      "$browser" = "firefox";

      #######################################################################
      # Monitors -- the UX425EA panel is 1920x1080. `hyprctl monitors` after
      # first boot if you attach anything external.
      #######################################################################
      monitor = [
        "eDP-1,1920x1080@60,0x0,1"
        ",preferred,auto,1" # any external display, to the right, unscaled
      ];

      #######################################################################
      # Startup
      #######################################################################
      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "awww-daemon"
        "nm-applet --indicator"
        "blueman-applet"
        # Clipboard history for both text and images.
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      #######################################################################
      # Input
      #######################################################################
      input = {
        kb_layout = "se";
        kb_options = "caps:escape"; # Caps Lock as Escape
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          disable_while_typing = true;
          scroll_factor = 0.6;
        };
      };

      gestures.workspace_swipe = true;

      #######################################################################
      # Look
      #######################################################################
      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(89b4faee) rgba(cba6f7ee) 45deg";
        "col.inactive_border" = "rgba(45475aaa)";
        layout = "dwindle";
        resize_on_border = true;
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
        };
        shadow = {
          enabled = true;
          range = 12;
          render_power = 2;
        };
      };

      animations = {
        enabled = true;
        bezier = [ "easeOutQuint,0.23,1,0.32,1" ];
        animation = [
          "windows,1,4,easeOutQuint"
          "workspaces,1,4,easeOutQuint,slide"
          "fade,1,3,default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
        vfr = true; # variable refresh when idle -- meaningful battery saving
      };

      #######################################################################
      # Key bindings
      #######################################################################
      bind = [
        # Launching
        "$mod, Return, exec, $terminal"
        "$mod, D, exec, $menu"
        "$mod, B, exec, $browser"
        "$mod, E, exec, nautilus"
        "$mod, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

        # Window management
        "$mod, Q, killactive,"
        "$mod, F, fullscreen, 0"
        "$mod SHIFT, F, togglefloating,"
        "$mod, P, pseudo,"
        "$mod, J, togglesplit,"
        "$mod SHIFT, Q, exit,"

        # Session
        "$mod, L, exec, loginctl lock-session"

        # Focus
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, H, movefocus, l"
        "$mod, semicolon, movefocus, r"

        # Move windows
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # Screenshots -- region, window, full screen; Shift annotates first.
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "$mod, Print, exec, grim - | wl-copy"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Media and brightness keys, repeating while held, and still live on the
      # lock screen (bindl).
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindl = [
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPrev, exec, playerctl previous"
      ];

      #######################################################################
      # Window rules
      #######################################################################
      windowrulev2 = [
        "suppressevent maximize, class:.*"
        # Fix occasional XWayland cursor scaling artefacts.
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

        "float, class:^(pavucontrol|blueman-manager|nm-connection-editor)$"
        "float, class:^(org.gnome.Calculator|gnome-disks)$"
        "float, title:^(Open File|Save File|Choose Files)$"

        # Games get their own workspace, no gaps, no blur.
        "workspace 9, class:^(steam_app_.*)$"
        "fullscreen, class:^(steam_app_.*)$"
        "immediate, class:^(steam_app_.*)$" # tearing allowed -> lower latency
      ];

      workspace = [
        "9, gapsin:0, gapsout:0, border:false, rounding:false"
      ];
    };
  };

  # A wallpaper is not set by default; drop a file at ~/Pictures/wallpaper.png
  # and set it with:  awww img ~/Pictures/wallpaper.png
}
