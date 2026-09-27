# Hyprland compositor configuration. The config itself is in ./hyprland.lua.
{ pkgs, ... }:
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
    extraConfig = builtins.readFile ./hyprland.lua;
  };

  # Lock / logout / suspend / hibernate / reboot / shut down, as a wofi list.
  # Bound to SUPER+SHIFT+Q and the power button in Waybar.
  home.packages = [
    # Body of the SUPER+SHIFT+C rebuild popup: runs `rebuild` (nh asks for
    # the sudo password only at the switch step), then notifies and waits.
    (pkgs.writeShellScriptBin "rebuild-popup" ''
      rebuild
      status=$?
      if [ "$status" -eq 0 ]; then
        ${pkgs.libnotify}/bin/notify-send -a rebuild "Rebuild done" "The new configuration is active."
        printf '\n\033[32mRebuild done.\033[0m Press any key to close.'
      else
        ${pkgs.libnotify}/bin/notify-send -a rebuild -u critical "Rebuild failed" "Exit code $status, see the rebuild window."
        printf '\n\033[31mRebuild failed (exit %s).\033[0m Press any key to close.' "$status"
      fi
      read -rsn1
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

  # A wallpaper is not set by default; drop a file at ~/Pictures/wallpaper.png
  # and set it with:  awww img ~/Pictures/wallpaper.png
}
