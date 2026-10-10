# Hyprland compositor configuration. The config itself is in ./hyprland.lua;
# the per-machine values it needs (monitors, backlight, repo paths) come from
# my.* (modules/host.nix) and are prepended as a Lua table called `host`.
{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  host = {
    inherit (osConfig.my) monitors backlight repos;
  };
in
{
  wayland.windowManager.hyprland = {
    enable = true;

    # Binds the session to systemd's graphical-session.target, which is what
    # Waybar / mako / hypridle key off. This is why we don't need UWSM.
    systemd = {
      enable = true;
      variables = [ "--all" ];
    };

    # Home Manager defaults to the Lua config format from stateVersion 26.05
    # on; hyprlang-style `settings` would be rendered as invalid Lua, so the
    # config lives in plain Lua instead.
    configType = "lua";
    extraConfig = ''
      -- Generated from my.* in the NixOS config (modules/host.nix).
      local host = ${lib.generators.toLua { } host}

    ''
    + builtins.readFile ./hyprland.lua;
  };

  # Lock / logout / suspend / hibernate / reboot / shut down, as a wofi list.
  # Bound to SUPER+SHIFT+Q and the power button in Waybar.
  home.packages = [
    # SUPER+SHIFT+R: rebuild in the background. A notification tracks it;
    # the root step goes through pkexec, so the polkit agent shows a
    # graphical password dialog once the build is done. On failure the
    # notification offers the log. One run at a time.
    (pkgs.writeShellScriptBin "rebuild-bg" ''
      notify() { ${pkgs.libnotify}/bin/notify-send -a rebuild "$@"; }
      log="''${XDG_CACHE_HOME:-$HOME/.cache}/rebuild.log"

      exec 9>"$XDG_RUNTIME_DIR/rebuild.lock"
      if ! ${pkgs.util-linux}/bin/flock -n 9; then
        notify "Rebuild already running" "Wait for the current one to finish."
        exit 1
      fi

      id=$(notify -p -t 0 "Rebuilding…" "You'll be asked for your password when the build is done.")
      start=$SECONDS
      if ${pkgs.nh}/bin/nh os switch ${osConfig.my.repos.nixos} --no-nom \
          --elevation-strategy /run/wrappers/bin/pkexec >"$log" 2>&1; then
        notify -r "$id" -t 8000 "Rebuild done" "Active after $((SECONDS - start))s."
      else
        action=$(notify -r "$id" -u critical -A "log=Show log" \
          "Rebuild failed" "$(tail -n 4 "$log")")
        [ "$action" = log ] && exec kitty --class rebuild-log less +G "$log"
      fi
    '')

    # `wallpaper <image>` sets the wallpaper; awww-daemon remembers it and
    # restores it at every login. `wallpaper --init` (run at Hyprland start)
    # sets a default only if nothing has ever been set.
    (pkgs.writeShellScriptBin "wallpaper" ''
      for _ in $(seq 50); do awww query >/dev/null 2>&1 && break; sleep 0.1; done
      if [ "$1" = "--init" ]; then
        # awww writes one cache file per monitor once an image has been set.
        cache="''${XDG_CACHE_HOME:-$HOME/.cache}/awww"
        [ -n "$(find "$cache" -type f -print -quit 2>/dev/null)" ] && exit 0
        set -- ${pkgs.nixos-artwork.wallpapers.nineish-dark-gray.gnomeFilePath}
      fi
      exec awww img --transition-type fade "$1"
    '')

    # claude-remote HOST SESSION DIR [CMD]: Claude Code (or CMD) in a tmux
    # session on HOST, for Claude panes with `remote` set in hyprland.lua.
    # tmux keeps it running there if the connection drops, and this
    # reattaches. Exit 0 means Claude exited or tmux was detached on purpose,
    # which closes the pane; anything else (255 = connection lost) retries.
    (pkgs.writeShellScriptBin "claude-remote" ''
      host=$1 session=$2 dir=$3 cmd=''${4:-claude --continue || claude}
      remote="tmux new-session -A -s $session -c $dir '$cmd'"
      remote+=" \; set -g mouse on \; set -g status off \; set -sg escape-time 10"
      remote+=" \; set -g history-limit 50000 \; set -as terminal-features ',xterm-256color:RGB'"
      # Copying: tmux passes selections to kitty as OSC 52, which puts them on
      # the laptop's clipboard (xterm-256color doesn't advertise it itself).
      remote+=" \; set -s set-clipboard on \; set -as terminal-features ',xterm-256color:clipboard'"
      # Native-feeling selection: releasing a drag copies but keeps the text
      # marked (instead of copy-and-cancel); a click returns to live output.
      for table in copy-mode copy-mode-vi; do
        remote+=" \; bind -T $table MouseDragEnd1Pane send -X copy-pipe-no-clear"
        remote+=" \; bind -T $table MouseDown1Pane send -X cancel"
      done
      while true; do
        # kitty's own TERM isn't known on the far side.
        TERM=xterm-256color ssh -t -o ControlMaster=no -o ConnectTimeout=10 \
          -o ServerAliveInterval=10 -o ServerAliveCountMax=3 "$host" "$remote"
        status=$?
        [ "$status" -eq 0 ] && exit 0
        printf '\n\033[33mLost the connection to %s (exit %s); reconnecting in 3s (Claude keeps running there in tmux)...\033[0m\n' "$host" "$status"
        sleep 3
      done
    '')

    # SUPER+C picker for the Claude scratchpads (hyprland.lua). ● marks a
    # session that is already running.
    (pkgs.writeShellScriptBin "claude-pick" ''
      clients=$(hyprctl clients -j)
      line() {
        if printf '%s' "$clients" | ${pkgs.jq}/bin/jq -e --arg c "claude-$1" 'any(.[]; .class == $c)' >/dev/null
        then echo "●  $1"; else echo "○  $1"; fi
      }
      choice=$({ line nixos; line dotfiles; line homelab; } \
        | wofi --dmenu --prompt "Claude" --width 260 --lines 4 --cache-file /dev/null) || exit 0
      hyprctl dispatch "claude_show(\"''${choice##* }\")" >/dev/null
    '')

    (pkgs.writeShellScriptBin "powermenu" ''
      choice=$(printf '%s\n' \
        "󰌾  Lock" "󰍃  Log out" "󰤄  Suspend" "󰒲  Hibernate" "󰜉  Reboot" "󰐥  Shut down" \
        | wofi --dmenu --prompt "Power" --width 260 --lines 7 --cache-file /dev/null)
      case "$choice" in
        *Lock)      loginctl lock-session ;;
        *"Log out") hyprctl dispatch 'hl.dsp.exit()' ;;
        *Suspend)   systemctl suspend ;;
        *Hibernate) systemctl hibernate ;;
        *Reboot)    systemctl reboot ;;
        *"Shut down") systemctl poweroff ;;
      esac
    '')
  ];

  # Night light: warm the screen in the evening, back to normal in the morning.
  services.hyprsunset = {
    enable = true;
    settings.profile = [
      {
        time = "07:00";
        identity = true;
      }
      {
        time = "20:30";
        temperature = 4000;
      }
    ];
  };
}
