# Change the Bose noise mode: `bose-mode toggle` (quiet <-> aware) or
# `bose-mode menu` (pick any mode in wofi). Then refresh custom/bose.
case "${1:-toggle}" in
  toggle)
    # `current` asks one question (~0.3 s); `status` would ask ~14 (~2.3 s).
    current=$(timeout 15 bosectl current 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || true)
    if [ "$current" = quiet ]; then new=aware; else new=quiet; fi
    ;;
  menu)
    new=$(printf '%s\n' quiet aware immersion cinema |
      wofi --dmenu --prompt "Bose mode" --width 240 --lines 5 --cache-file /dev/null) || exit 0
    ;;
  *)
    echo "usage: bose-mode toggle|menu" >&2
    exit 1
    ;;
esac
timeout 15 bosectl "$new" >/dev/null
pkill -RTMIN+8 waybar || true # signal = 8 in custom/bose
