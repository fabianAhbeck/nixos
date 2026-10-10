# Low-battery warnings on laptops (my.laptop): a pop-up at 15% and a
# critical one at 5%. At 3% UPower hibernates (hosts/<name>/default.nix).
{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  battery-warn = pkgs.writeShellApplication {
    name = "battery-warn";
    runtimeInputs = [ pkgs.libnotify ];
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
