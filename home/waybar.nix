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
    pkgs.mission-center
    pkgs.gsimplecal
    (pkgs.writeShellScriptBin "calendar-popup" ''
      if pgrep -x gsimplecal >/dev/null; then
        exec gsimplecal # a second instance closes the first
      fi
      GTK_THEME=gsimplecal-catppuccin exec gsimplecal
    '')
  ];
  # Catppuccin Mocha on top of Adwaita-dark, sized to match the bar: mauve
  # month/year, blue arrows, weekdays and week numbers, today as a blue pill.
  xdg.dataFile."themes/gsimplecal-catppuccin/gtk-3.0/gtk.css".text = ''
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
        interval = 5;
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
        on-click = "blueman-manager";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons.default = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
        on-click = "pavucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
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
