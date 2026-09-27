# Hyprland compositor configuration. The config itself is in ./hyprland.lua.
{ ... }:
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

  # A wallpaper is not set by default; drop a file at ~/Pictures/wallpaper.png
  # and set it with:  awww img ~/Pictures/wallpaper.png
}
