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
