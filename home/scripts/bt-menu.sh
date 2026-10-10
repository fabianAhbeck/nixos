# SUPER+B / Waybar Bluetooth click: paired devices in wofi (● connected,
# ○ not); pick one to connect or disconnect it. Plus Bluetooth on/off and
# blueman for pairing new devices.
notify() { notify-send -a bluetooth -t 4000 "$@"; }
connected() { bluetoothctl info "$1" | grep -m1 -q '^[[:space:]]*Connected: yes'; }
powered() { bluetoothctl show | grep -q '^[[:space:]]*Powered: yes'; }

declare -A mac_of
entries=()
while read -r _ mac name; do
  [ -n "$mac" ] || continue
  if powered && connected "$mac"; then line="●  $name"; else line="○  $name"; fi
  entries+=("$line")
  mac_of["$line"]=$mac
done < <(bluetoothctl devices Paired)

if powered; then toggle="Turn Bluetooth off"; else toggle="Turn Bluetooth on"; fi
choice=$(printf '%s\n' "${entries[@]}" "$toggle" "Bluetooth settings…" |
  wofi --dmenu --prompt Bluetooth --width 360 --lines $((${#entries[@]} + 3)) \
    --cache-file /dev/null) || exit 0

case "$choice" in
  "Turn Bluetooth on") bluetoothctl power on >/dev/null && notify "Bluetooth on"; exit 0 ;;
  "Turn Bluetooth off") bluetoothctl power off >/dev/null && notify "Bluetooth off"; exit 0 ;;
  "Bluetooth settings…") exec blueman-manager ;;
esac

mac=${mac_of["$choice"]:-}
[ -n "$mac" ] || exit 0
name=${choice#*  }
powered || bluetoothctl power on >/dev/null
if connected "$mac"; then
  if timeout 15 bluetoothctl disconnect "$mac" >/dev/null; then
    notify "Disconnected" "$name"
  else
    notify -u critical "Couldn't disconnect" "$name"
  fi
else
  notify "Connecting…" "$name"
  if timeout 20 bluetoothctl connect "$mac" >/dev/null; then
    notify "Connected" "$name"
  else
    notify -u critical "Couldn't connect" "$name — is it on and nearby?"
  fi
fi
pkill -RTMIN+8 waybar || true # refresh the Bose item (custom/bose)
