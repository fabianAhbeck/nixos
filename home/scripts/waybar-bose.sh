# Waybar custom/bose: the connected Bose earbuds/headphones' noise mode and
# battery, read from the device (waybar-bose.py, via bosectl's library).
# No Bose device connected -> empty text, which hides the module.
if ! bluetoothctl devices Connected 2>/dev/null | grep -qi bose; then
  echo '{"text": ""}'
  exit 0
fi
timeout 15 python3 "$WAYBAR_BOSE_PY" ||
  echo '{"text": "󰋋 ?", "tooltip": "Bose: no answer from the device", "class": "unknown"}'
