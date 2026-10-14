# Reminder to run `update` (home/shell.nix) once the pinned nixpkgs is a
# week old: a pop-up at most once a day, with an "Update now" button, and
# "↻ 9d" in the bar until it's done. Age is that of the running system's
# nixpkgs (the date in its version, 26.11.20260926.e158d9e), i.e. how old
# the installed packages are: an updated flake.lock that was never rebuilt
# doesn't count.
{ lib, pkgs, ... }:
let
  days = 7;

  update-check = pkgs.writeShellApplication {
    name = "update-check";
    runtimeInputs = with pkgs; [
      jq
      libnotify
      kitty
    ];
    text = ''
      version=$(cat /run/current-system/nixos-version)
      since=$(date -d "$(cut -d. -f3 <<<"$version")" +%F)
      age=$(( ($(date +%s) - $(date -d "$since" +%s)) / 86400 ))

      if [ "''${1:-}" = --waybar ]; then
        if [ "$age" -ge ${toString days} ]; then
          jq -cn --arg t "↻ ''${age}d" --arg tip "Packages from $since. Click to update." \
            '{text: $t, tooltip: $tip, class: "stale"}'
        else
          echo '{"text": ""}' # hides the item
        fi
        exit 0
      fi

      [ "$age" -ge ${toString days} ] || exit 0
      stamp=''${XDG_STATE_HOME:-$HOME/.local/state}/update-reminder
      [ "$(cat "$stamp" 2>/dev/null)" = "$(date +%F)" ] && exit 0
      date +%F > "$stamp"
      action=$(notify-send -a update -i system-software-update -A "update=Update now" \
        "Time to update" "Packages are $age days old (from $since).")
      [ "$action" = update ] && exec kitty --hold update
      exit 0
    '';
  };
in
{
  home.packages = [ update-check ];

  # Hourly, but it pops up at most once a day (and only once it's due), so
  # it also catches days the laptop was asleep at any fixed time.
  systemd.user.services.update-reminder = {
    Unit.Description = "Remind to update once packages are a week old";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe update-check;
    };
  };
  systemd.user.timers.update-reminder = {
    Unit.Description = "Check package age hourly";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Listed in modules-right in waybar.nix. Refreshed hourly and right after
  # `update` (signal 9).
  programs.waybar.settings.mainBar."custom/update" = {
    exec = "${lib.getExe update-check} --waybar";
    return-type = "json";
    interval = 3600;
    signal = 9;
    on-click = "kitty --hold update";
  };
}
