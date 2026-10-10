# Laptops (my.laptop): low-battery pop-ups at 15% and 5%, and window blur
# only while charging. At 3% UPower hibernates (hosts/<name>/default.nix).
{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  battery-warn = pkgs.writeShellApplication {
    name = "battery-warn";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.hyprland # hyprctl, for blur on/off
    ];
    text = builtins.readFile ./scripts/battery-warn.sh;
  };
in
lib.mkIf osConfig.my.laptop {
  systemd.user.services.battery-warn = {
    Unit.Description = "Low-battery warning";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe battery-warn;
    };
  };
  systemd.user.timers.battery-warn = {
    Unit.Description = "Check the battery level every minute";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
