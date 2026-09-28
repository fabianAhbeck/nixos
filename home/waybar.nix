# Status bar.
{ pkgs, lib, ... }:
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
        "battery"
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
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "month";
          weeks-pos = "right";
          format.today = "<b>{}</b>";
        };
        actions.on-click-right = "mode";
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
        # Tiger Lake package sensor.
        hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
        input-filename = "temp1_input";
        critical-threshold = 85;
        format = " {temperatureC}°C";
        format-critical = " {temperatureC}°C";
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

      #battery.warning  { color: #f9e2af; }
      #battery.critical { color: #f38ba8; }
      #temperature.critical { color: #f38ba8; }
      #network.disconnected { color: #f38ba8; }
      #custom-power { color: #f38ba8; padding-right: 14px; }
    '';
  };
}
