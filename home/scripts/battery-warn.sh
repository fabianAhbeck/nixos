# Low-battery pop-ups: once at 15%, again (critical, stays until dismissed)
# at 5%. Plugging in resets them. Run every minute by battery-warn.timer.
bat=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' | head -1)
[ -n "$bat" ] || exit 0
capacity=$(cat "$bat/capacity")
status=$(cat "$bat/status")
warned="${XDG_RUNTIME_DIR:-/tmp}/battery-warned" # last level warned about

if [ "$status" != Discharging ]; then
  rm -f "$warned"
  exit 0
fi
last=$(cat "$warned" 2>/dev/null || echo 100)

if [ "$capacity" -le 5 ] && [ "$last" -gt 5 ]; then
  notify-send -a battery -u critical -i battery-caution \
    "Battery critical: $capacity%" "Plug in now. The laptop hibernates at 3%."
  echo 5 >"$warned"
elif [ "$capacity" -le 15 ] && [ "$last" -gt 15 ]; then
  notify-send -a battery -u normal -t 15000 -i battery-low \
    "Battery low: $capacity%" "Time to find a charger."
  echo 15 >"$warned"
fi
