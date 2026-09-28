# Status bar. Battery and the CPU temperature sensor follow my.laptop and
# my.cpuTempSensor (modules/host.nix).
{
  lib,
  osConfig,
  ...
}:
{
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
        "temperature"
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
        # Hover for the calendar: scroll over the clock to change month,
        # click to jump back to today, right-click for the whole year.
        tooltip-format = "<tt><span size='large'>{calendar}</span></tt>";
        calendar = {
          mode = "month";
          mode-mon-col = 3; # year view: 3 months per row
          weeks-pos = "right";
          on-scroll = 1;
          format = {
            months = "<span color='#cba6f7'><b>{}</b></span>";
            weekdays = "<span color='#89b4fa'><b>{}</b></span>";
            weeks = "<span color='#6c7086'>{}</span>";
            days = "<span color='#cdd6f4'>{}</span>";
            today = "<span color='#1e1e2e' background='#89b4fa'><b>{}</b></span>";
          };
        };
        actions = {
          on-click = "shift_reset";
          on-click-right = "mode";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };

      cpu = {
        format = "󰻠 {usage}%";
        interval = 5;
        on-click = "kitty -e btop";
      };

      memory = {
        format = "󰍛 {percentage}%";
        interval = 10;
        tooltip-format = "{used:0.1f}G / {total:0.1f}G";
      };

      temperature = {
        critical-threshold = 85;
        format = " {temperatureC}°C";
        format-critical = " {temperatureC}°C";
      }
      // lib.optionalAttrs (osConfig.my.cpuTempSensor != null) {
        hwmon-path-abs = osConfig.my.cpuTempSensor;
        input-filename = "temp1_input";
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
      #temperature,
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
      #temperature.critical { color: #f38ba8; }
      #network.disconnected { color: #f38ba8; }
      #custom-power { color: #f38ba8; padding-right: 14px; }
    '';
  };
}
