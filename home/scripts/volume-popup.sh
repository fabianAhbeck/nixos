# Waybar volume click: a small slider for the default output (yad --scale).
# Dragging sets the volume live; clicking the icon again, or anywhere else,
# closes it. Moving the slider also unmutes.
# Skip a click on the bar icon that just closed this popup from the outside
# (hyprland.lua closes bar popups on clicks outside them).
closed="${XDG_RUNTIME_DIR:-/tmp}/bar-popup-closed"
if [ -f "$closed" ] &&
  [ $(($(date +%s%3N) - $(LC_ALL=C stat -c %.3Y "$closed" | tr -d .))) -lt 1000 ]; then
  exit 0
fi

if pkill -f 'yad --scale --title=Volume'; then
  exit 0 # it was open: this click closes it
fi

sink=@DEFAULT_AUDIO_SINK@
read -r _ vol muted < <(wpctl get-volume "$sink")
vol=$(awk -v v="$vol" 'BEGIN { printf "%d", v * 100 }')
# "500 Series ... (HD Audio) Speaker" -> "Speaker"; "Bose QC Ultra 2 Earbuds" stays.
name=$(wpctl inspect "$sink" | sed -n 's/.*node\.description = "\(.*\)"/\1/p' | head -1 | sed 's/.*) //')
label="${name:-Volume}${muted:+  (muted)}"

GTK_THEME=catppuccin-popup yad --scale --title=Volume --text="$label" \
  --value="$vol" --min-value=0 --max-value=100 --step=1 --print-partial \
  --undecorated --no-buttons --skip-taskbar --close-on-unfocus |
  while read -r v; do
    wpctl set-volume "$sink" "${v%.*}%"
    [ -z "$muted" ] || { wpctl set-mute "$sink" 0; muted=""; }
  done
