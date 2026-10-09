# Waybar custom/bose: the connected Bose earbuds/headphones' noise mode and
# battery, read from the device with bosectl. No Bose device connected ->
# empty text, which hides the module.
if ! bluetoothctl devices Connected 2>/dev/null | grep -qi bose; then
  echo '{"text": ""}'
  exit 0
fi

status=$(timeout 15 bosectl status 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || true)
field() { awk -v k="$1" '$1 == k { $1 = ""; sub(/^ +/, ""); print; exit }' <<<"$status"; }
mode=$(field Mode)
battery=$(field Battery)

if [ -z "$mode" ]; then
  jq -cn '{text: "󰋋 ?", tooltip: "Bose: no answer from the device", class: "unknown"}'
  exit 0
fi

case "$mode" in
  aware) icon="󰟅" ;;                # ear: transparency
  immersion | cinema) icon="󰗅" ;;   # spatial audio
  *) icon="󰋋" ;;                    # headphones: quiet / full ANC
esac
tooltip="$(field Name)
Mode: $mode ($(field CNC))
Battery: $battery
Click: quiet / aware   Right-click: all modes"
jq -cn --arg text "$icon $battery" --arg tooltip "$tooltip" --arg class "$mode" \
  '{text: $text, tooltip: $tooltip, class: $class}'
