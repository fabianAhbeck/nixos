# Status bar. The battery module follows my.laptop (modules/host.nix).
{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # The package is mission-center, the binary missioncenter.
  missionCenter = "${pkgs.mission-center}/bin/missioncenter";
in
{
  # Click the clock for a month calendar with ‹ › buttons (gsimplecal).
  # Clicking again closes it, as does clicking elsewhere. Over a Claude pane
  # it opens on top of it (it's exempt from the pane guard in hyprland.lua).
  # It runs with its own GTK theme (below), so other GTK apps keep plain
  # Adwaita-dark.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "bt-menu";
      runtimeInputs = with pkgs; [
        bluez
        wofi
        libnotify
        procps
      ];
      text = builtins.readFile ./scripts/bt-menu.sh;
    })
    (pkgs.writeShellApplication {
      name = "volume-popup";
      runtimeInputs = with pkgs; [
        yad
        wireplumber # wpctl
        procps # pkill
        gawk
        gnused
      ];
      text = builtins.readFile ./scripts/volume-popup.sh;
    })
    pkgs.mission-center
    pkgs.gsimplecal
    (pkgs.writeShellScriptBin "calendar-popup" ''
      # Skip a click on the bar icon that just closed this popup from the outside
      # (hyprland.lua closes bar popups on clicks outside them).
      closed="''${XDG_RUNTIME_DIR:-/tmp}/bar-popup-closed"
      if [ -f "$closed" ] &&
        [ $(($(date +%s%3N) - $(LC_ALL=C stat -c %.3Y "$closed" | tr -d .))) -lt 1000 ]; then
        exit 0
      fi

      if pgrep -x gsimplecal >/dev/null; then
        exec gsimplecal # a second instance closes the first
      fi
      GTK_THEME=catppuccin-popup exec gsimplecal
    '')
  ];
  # Catppuccin Mocha on top of Adwaita-dark for the bar's popups (calendar,
  # volume slider), sized to match the bar: mauve month/year, blue arrows,
  # weekdays and week numbers, today as a blue pill; blue slider fill.
  xdg.dataFile."themes/catppuccin-popup/gtk-3.0/gtk.css".text = ''
    @import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");

    window, .background {
      background-color: #1e1e2e;
      color: #cdd6f4;
    }
    calendar, calendar.view {
      font-family: "Inter";
      font-size: 10pt;
      padding: 1px 3px; /* per day cell */
      background-color: #1e1e2e;
      color: #cdd6f4;
      border: none;
    }
    calendar.header {
      background-color: transparent;
      border: none;
      color: #cba6f7;
      font-weight: bold;
    }
    calendar.button { color: #89b4fa; }
    calendar.button:hover { color: #b4befe; }
    calendar.highlight {
      background-color: transparent;
      color: #89b4fa;
      font-weight: bold;
    }
    calendar:indeterminate { color: #585b70; }
    calendar:selected {
      background-color: #89b4fa;
      color: #1e1e2e;
      border-radius: 6px;
      font-weight: bold;
    }

    /* Sliders (the volume popup) */
    label { color: #cdd6f4; font-family: "Inter"; font-size: 10pt; }
    scale { padding: 6px 4px; }
    scale trough {
      background-color: #313244;
      border: none;
      border-radius: 6px;
      min-height: 8px;
    }
    scale highlight {
      background-color: #89b4fa;
      border: none;
      border-radius: 6px;
    }
    scale slider {
      background-color: #b4befe;
      background-image: none; /* Adwaita's gradient would hide the colour */
      border: 2px solid #1e1e2e;
      border-radius: 50%;
      min-width: 16px;
      min-height: 16px;
      box-shadow: none;
    }
    scale value { color: #cdd6f4; font-family: "Inter"; }
  '';
  xdg.configFile."gsimplecal/config".text = ''
    show_calendar = 1
    show_timezones = 0
    mark_today = 1
    show_week_numbers = 1
    close_on_unfocus = 1
    mainwindow_decorated = 0
    mainwindow_keep_above = 1
    mainwindow_skip_taskbar = 1
    mainwindow_resizable = 0
    mainwindow_position = none
  '';

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = [ "graphical-session.target" ];
    };

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      spacing = 8;

      modules-left = [
        "hyprland/workspaces"
        "hyprland/submap"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "privacy"
        "pulseaudio"
        "custom/bose"
        "bluetooth"
        "network"
        "cpu"
        "memory"
        "custom/temps"
      ]
      ++ lib.optional osConfig.my.laptop "battery"
      ++ [
        "custom/power"
      ];

      "hyprland/workspaces" = {
        # Workspace number; the active one is highlighted via CSS below.
        format = "{name}";
        on-click = "activate";
        persistent-workspaces."*" = 5;
      };

      clock = {
        # ISO-ish, which is what Swedish locale gives you anyway.
        format = "{:%a %d %b  %H:%M}";
        # The calendar is a popup (calendar-popup above), so no tooltip.
        tooltip = false;
        on-click = "calendar-popup";
      };

      # Clicking CPU, memory or temperature opens Mission Center, a graphical
      # system monitor (btop is still there in a terminal).
      cpu = {
        format = " {usage}%";
        interval = 5;
        on-click = missionCenter;
      };

      memory = {
        format = " {percentage}%";
        interval = 10;
        on-click = missionCenter;
        tooltip-format = "{used:0.1f}G / {total:0.1f}G";
      };

      # CPU temperature in the bar; hover for every sensor (cores, SSD,
      # motherboard, Wi-Fi, ...), colour-coded. See scripts/waybar-temps.sh.
      "custom/temps" = {
        exec = lib.getExe (
          pkgs.writeShellApplication {
            name = "waybar-temps";
            runtimeInputs = [ pkgs.jq ];
            text = builtins.readFile ./scripts/waybar-temps.sh;
          }
        );
        return-type = "json";
        interval = 15; # each run reads every sensor; 15 s is plenty
        format = " {}";
        on-click = missionCenter;
      };

      battery = {
        states = {
          warning = 25;
          critical = 10;
        };
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-plugged = "󰚥 {capacity}%";
        format-icons = [
          "󰁺"
          "󰁽"
          "󰁿"
          "󰂂"
          "󰁹"
        ];
        # Charging stops at 80% (hardware.asus.battery.chargeUpto), so don't
        # read "not full" as a fault.
        tooltip-format = "{timeTo}\n{power}W";
      };

      network = {
        format-wifi = "󰖩 {signalStrength}%";
        format-ethernet = "󰈀 {ifname}";
        format-disconnected = "󰖪";
        tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
        on-click = "networkmanager_dmenu";
        on-click-right = "nm-connection-editor";
      };

      bluetooth = {
        format = "󰂯";
        format-disabled = "";
        format-connected = "󰂱 {num_connections}";
        tooltip-format-connected = "{device_enumerate}";
        on-click = "bt-menu"; # paired devices: connect / disconnect
        on-click-right = "blueman-manager";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons.default = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
        # Click: volume slider; right-click: the full mixer; middle-click:
        # mute. Scrolling over it steps the volume.
        on-click = "volume-popup";
        on-click-right = "pavucontrol";
        on-click-middle = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      # Shows an indicator when something is recording the screen or mic.
      privacy = {
        icon-spacing = 4;
        modules = [
          { type = "screenshare"; }
          { type = "audio-in"; }
        ];
      };

      "custom/power" = {
        format = "󰐥";
        tooltip-format = "Power menu";
        on-click = "powermenu";
      };

      tray = {
        icon-size = 16;
        spacing = 8;
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Inter";
        font-size: 12px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: rgba(30, 30, 46, 0.92);
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 8px;
        color: #6c7086;
        background: transparent;
      }
      #workspaces button.active {
        color: #1e1e2e;
        background: #89b4fa;
        font-weight: 700;
      }
      #workspaces button.urgent {
        color: #f38ba8;
      }
      #workspaces button:hover {
        background: rgba(137, 180, 250, 0.15);
      }
      #workspaces button.active:hover {
        background: #89b4fa;
      }

      #clock,
      #cpu,
      #memory,
      #custom-temps,
      #battery,
      #network,
      #bluetooth,
      #pulseaudio,
      #privacy,
      #custom-power,
      #custom-bose,
      #tray {
        padding: 0 10px;
      }

      #clock {
        font-weight: 600;
      }

      tooltip {
        background: #1e1e2e;
        border: 2px solid #89b4fa;
        border-radius: 10px;
      }
      tooltip label {
        color: #cdd6f4;
        padding: 4px 6px;
      }

      #battery.warning  { color: #f9e2af; }
      #battery.critical { color: #f38ba8; }
      #custom-temps.critical { color: #f38ba8; }
      #network.disconnected { color: #f38ba8; }
      #custom-power { color: #f38ba8; padding-right: 14px; }
    '';
  };
}
