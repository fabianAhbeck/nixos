# Stay-awake mode, for walking away from a long job: `stay-awake` (SUPER+I)
# toggles a systemd inhibitor lock that stops idle suspend (hypridle honours
# it), any other suspend and the lid switch. A coffee cup in the bar while
# it's on; nothing otherwise. `systemd-inhibit --list` shows the lock.
{ lib, pkgs, ... }:
let
  match = "systemd-inhibit --who=stay-awake";

  stay-awake = pkgs.writeShellApplication {
    name = "stay-awake";
    runtimeInputs = with pkgs; [
      procps
      systemd
      util-linux # setsid
      libnotify
    ];
    text = ''
      pid=$(pgrep -o -u "$(id -u)" -f "${match}" || true)

      if [ "''${1:-}" = --waybar ]; then
        if [ -n "$pid" ]; then
          # \n stays literal: it's JSON's newline, for the tooltip.
          printf '%s\n' '{"text": "󰅶", "class": "on", "tooltip": "Staying awake: no suspend on idle or lid close.\nSUPER+I or click to turn off."}'
        else
          echo '{"text": ""}' # hides the item
        fi
        exit 0
      fi

      if [ -n "$pid" ]; then
        # setsid made it a process group leader: this ends its `sleep` too.
        kill -- "-$pid"
        notify-send -a stay-awake -i weather-clear-night "Stay awake off" "Sleeps on idle and lid close again."
      else
        setsid -f ${match} --what=idle:sleep:handle-lid-switch \
          --why="Stay-awake mode (SUPER+I)" sleep infinity
        notify-send -a stay-awake -i weather-clear "Stay awake on" "No suspend on idle or lid close until SUPER+I again."
      fi
      pkill -RTMIN+10 waybar || true
    '';
  };
in
{
  home.packages = [ stay-awake ];

  # Refreshed right after a toggle (signal 10); the interval catches a lock
  # ended some other way.
  programs.waybar.settings.mainBar."custom/awake" = {
    exec = "${lib.getExe stay-awake} --waybar";
    return-type = "json";
    interval = 30;
    signal = 10;
    on-click = lib.getExe stay-awake;
  };
}
