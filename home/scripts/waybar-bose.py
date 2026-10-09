"""Waybar custom/bose: one connection, only what the bar shows.

`bosectl status` asks ~14 questions (~2.3 s over Bluetooth); this asks 4
(battery, mode, noise cancelling, name: ~0.8 s). Prints one JSON line.
"""
import json

import pybmap

ICONS = {"aware": "󰟅", "immersion": "󰗅", "cinema": "󰗅"}  # default: 󰋋


def meter(strength):
    return "█" * strength + "░" * (10 - strength)


try:
    with pybmap.connect() as dev:
        battery = dev.battery_status()
        mode = dev.mode() or "unknown"
        cnc_level, cnc_max = dev.cnc() or (None, None)
        name = dev.name()
        components = dev.battery_components or {}
except Exception as error:  # no answer, busy, out of range...
    print(json.dumps({"text": "󰋋 ?", "tooltip": f"Bose: no answer ({error})",
                      "class": "unknown"}))
    raise SystemExit(0)

lines = [name, f"Mode: {mode}"]
# Bose counts 0 = maximum noise cancelling; show strength, 10 = max.
if cnc_level is not None and cnc_max == 10:
    strength = 10 - cnc_level
    lines.append(f"Noise cancelling: {meter(strength)} {strength}/10")
parts = [f"{label} {level}%" for cid, label in components.items()
         for reading_id, level in battery.readings if reading_id == cid]
lines.append(f"Battery: {battery.aggregate}%" + (f" ({', '.join(parts)})" if parts else ""))
lines.append("Click: quiet / aware   Right-click: all modes")

print(json.dumps({
    "text": f"{ICONS.get(mode, '󰋋')} {battery.aggregate}%",
    "tooltip": "\n".join(lines),
    "class": mode,
}))
