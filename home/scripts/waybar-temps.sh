# Waybar custom module: CPU temperature in the bar, every hwmon sensor in
# the tooltip, colour-coded. Prints one JSON line.
colour() { # °C -> Catppuccin green / yellow / red
  if [ "$1" -ge 80 ]; then echo "#f38ba8"; elif [ "$1" -ge 60 ]; then echo "#f9e2af"; else echo "#a6e3a1"; fi
}
cpu="" max=0 cpu_rows=() rows=()
for h in /sys/class/hwmon/hwmon*; do
  name=$(cat "$h/name" 2>/dev/null) || continue
  for input in "$h"/temp*_input; do
    [ -r "$input" ] || continue
    t=$(( $(cat "$input" 2>/dev/null || echo 0) / 1000 ))
    [ "$t" -gt 0 ] || continue
    label=$(cat "${input%_input}_label" 2>/dev/null || true) # not every sensor has one
    case "$name:$label" in
      coretemp:Package* | k10temp:Tctl | k10temp:Tdie) label="CPU"; cpu=$t ;;
      coretemp:Core*) label="  core ${label#Core }" ;;
      nvme:*) label="NVMe SSD" ;;
      acpitz:*) label="Motherboard" ;;
      iwlwifi*:* | mt7*:* | ath*:*) label="Wi-Fi" ;;
      amdgpu:*) label="GPU${label:+ ($label)}" ;;
      *) label="$name${label:+ $label}" ;;
    esac
    [ "$t" -gt "$max" ] && max=$t
    row=$(printf "%-13s <span color='%s'>%3d°C</span>" "$label" "$(colour "$t")" "$t")
    case "$name" in coretemp | k10temp) cpu_rows+=("$row") ;; *) rows+=("$row") ;; esac
  done
done
cpu=${cpu:-$max}
class=""; [ "$cpu" -ge 85 ] && class="critical"
tooltip=$(printf '%s\n' "${cpu_rows[@]}" "${rows[@]}")
jq -cn --arg text "$cpu°C" --arg tooltip "<tt>$tooltip</tt>" --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
