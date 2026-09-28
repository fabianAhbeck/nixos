# Per-machine settings, declared once and read by both the system modules
# and Home Manager (as osConfig.my.*). Each hosts/<name>/default.nix sets
# them; the defaults suit a machine with nothing special attached.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.my = {
    repos = {
      nixos = mkOption {
        type = types.str;
        default = "/home/fabian/Projects/nixos";
        description = "Checkout of this repo: rebuilds, NH_FLAKE, the Claude pane.";
      };
      dotfiles = mkOption {
        type = types.str;
        default = "/home/fabian/Projects/dotfiles";
        description = "Checkout of the dotfiles repo (nvim config, its Claude pane).";
      };
      homelab = mkOption {
        type = types.str;
        default = "/home/fabian/Projects/homelab";
        description = "Homelab configs (nixos-configs/ inside), for its Claude pane.";
      };
    };

    monitors = mkOption {
      description = ''
        Monitors for Hyprland, in hl.monitor() form. Anything not listed gets
        its preferred mode, placed automatically at scale 1. The scale keys
        (SUPER + plus/minus) step through scales that divide `mode` evenly.
      '';
      default = [ ];
      type = types.listOf (
        types.submodule {
          options = {
            output = mkOption {
              type = types.str;
              example = "DP-1";
            };
            mode = mkOption {
              type = types.str;
              example = "3440x1440@144";
            };
            position = mkOption {
              type = types.str;
              default = "auto";
            };
            scale = mkOption {
              type = types.number;
              default = 1;
            };
          };
        }
      );
    };

    backlight = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "intel_backlight";
      description = "Backlight device for the brightness keys (brightnessctl -l); null on desktops.";
    };

    laptop = mkOption {
      type = types.bool;
      default = false;
      description = "Show battery status in Waybar.";
    };

    cpuTempSensor = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/sys/devices/platform/coretemp.0/hwmon";
      description = "hwmon directory for Waybar's CPU temperature; null uses the default thermal zone.";
    };
  };
}
