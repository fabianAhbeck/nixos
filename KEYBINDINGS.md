# Keybindings

Cheat-sheet for the Hyprland setup. The bindings live in
[`home/hyprland.lua`](home/hyprland.lua); update this file when you change
them. `SUPER` is the Windows key.

## Apps

| Keys | Action |
| --- | --- |
| `SUPER + Return` | Terminal (kitty) |
| `SUPER + D` | App launcher (wofi) |
| `SUPER + W` | Firefox |
| `SUPER + E` | File manager (Nautilus) |
| `SUPER + N` | Wi-Fi / VPN menu (also: click the network icon in Waybar; right-click for the full editor) |
| `SUPER + V` | Clipboard history, pick an entry to copy it |
| `SUPER + C` | Show/hide Claude Code: the session you used last (nixos by default). Each resumes its repo's last conversation |
| `SUPER + ALT + C` | Pick which Claude session to show (nixos / dotfiles; ● = running); SUPER + C then toggles that one |
| `SUPER + SHIFT + C` | Rebuild the system in the background; a notification tracks it and a password dialog appears when the build is done |

## Windows

| Keys | Action |
| --- | --- |
| `SUPER + Q` | Close window |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + SHIFT + F` | Toggle floating |
| `SUPER + P` | Pseudo-tile (keep the window's own size inside its tile) |
| `SUPER + T` | Switch split direction (side by side / stacked) |
| `SUPER + arrows` or `SUPER + H/J/K/L` | Move focus (vim keys: left/down/up/right) |
| `SUPER + SHIFT + arrows` or `SUPER + SHIFT + H/J/K/L` | Move window |
| `SUPER + left-drag` | Move window with the mouse |
| `SUPER + right-drag` | Resize window with the mouse |

## Workspaces

| Keys | Action |
| --- | --- |
| `SUPER + 1` … `SUPER + 9`, `SUPER + 0` | Go to workspace 1–9, 10 |
| `SUPER + SHIFT + 1` … `0` | Move window to workspace 1–10 |
| `SUPER + scroll` | Next / previous workspace |
| Three-finger swipe (touchpad) | Next / previous workspace |
| `SUPER + S` | Show/hide the scratchpad workspace |
| `SUPER + SHIFT + S` | Move window to the scratchpad |

## Session

| Keys | Action |
| --- | --- |
| `SUPER + Escape` (or `SUPER + Caps Lock`) | Lock screen |
| `SUPER + SHIFT + Q` | Power menu: lock, log out, suspend, hibernate, reboot, shut down |

The power menu is also the red button at the right end of Waybar.

## Screenshots

| Keys | Action |
| --- | --- |
| `Print` | Select a region, copy to clipboard |
| `SHIFT + Print` | Select a region, annotate in swappy |
| `SUPER + Print` | Whole screen, copy to clipboard |

## Media and brightness

These work on the lock screen too; volume and brightness repeat while held.

| Keys | Action |
| --- | --- |
| Volume up / down | ±5%, capped at 100% |
| Mute | Toggle speaker mute |
| Mic mute | Toggle microphone mute |
| Play / Next / Previous | Media player control |
| Brightness up / down | Screen brightness ±5% |

## Terminal commands

| Command | What it does |
| --- | --- |
| `rebuild` | Build and switch to the config in this repo |
| `rebuild-test` / `rebuild-boot` | Switch without a boot entry / only on next boot |
| `update` | Update flake inputs (then `rebuild`) |
| `gc` | Delete old generations now (also runs weekly) |
| `wallpaper <image>` | Set the wallpaper; it is restored at every login |
| `powermenu` | The power menu, from a terminal |
