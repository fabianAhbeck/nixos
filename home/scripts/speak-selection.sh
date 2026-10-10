# Read the highlighted text (or the clipboard) aloud with Piper, locally.
# Run it again while it's speaking to stop. VOICE and RATE come from
# home/speech.nix.
state="${XDG_RUNTIME_DIR:-/tmp}/speak-selection"
pgid_file="$state.pgid"

# Already speaking: stop it (kill the whole piper | pw-cat process group).
if [ -f "$pgid_file" ]; then
  pgid=$(cat "$pgid_file")
  rm -f "$pgid_file"
  if kill -0 -- "-$pgid" 2>/dev/null; then
    kill -- "-$pgid"
    exit 0
  fi
fi

# Normally the highlighted text (primary selection), else the clipboard. In
# a remote Claude pane (tmux over ssh) a mouse selection never reaches the
# primary selection, but tmux sends it to the laptop clipboard (OSC 52), so
# there read the clipboard first.
active=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' || true)
if [[ " $REMOTE_PANES " == *" $active "* ]]; then
  text=$(wl-paste --no-newline 2>/dev/null || true)
else
  text=$(wl-paste --primary --no-newline 2>/dev/null || true)
  [ -n "$text" ] || text=$(wl-paste --no-newline 2>/dev/null || true)
fi
if [ -z "$text" ]; then
  notify-send -a speak -t 3000 "Nothing to read" "Select some text first."
  exit 0
fi
printf '%s\n' "$text" >"$state.txt"

# setsid: own process group, so the stop above can kill piper and pw-cat
# together. The group's leader writes its pid as the group id.
# shellcheck disable=SC2016 # the inner script expands its own $1..$4
setsid bash -c '
  echo $$ >"$1"
  piper -m "$2" --output-raw <"$3" 2>/dev/null |
    pw-cat --playback --raw --rate "$4" --channels 1 --format s16 -
  rm -f "$1"
' speak "$pgid_file" "$VOICE" "$state.txt" "$RATE" &
