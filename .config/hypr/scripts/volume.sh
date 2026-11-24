#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ACTION="${1:-}"
case "$ACTION" in
  up | down | mute | mic-mute) ;;
  *)
    echo "Usage: volume.sh {up|down|mute|mic-mute}" >&2
    exit 2
    ;;
esac

if command -v wpctl >/dev/null 2>&1; then
  case "$ACTION" in
    up)
      RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
      CURRENT=$(printf '%s\n' "$RAW" | awk '/^Volume:/ {printf "%.0f", $2 * 100}')
      [[ "$CURRENT" =~ ^[0-9]+$ ]] || exit 0
      [ "$CURRENT" -ge 100 ] && exit 0
      wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0 2>/dev/null || exit 0
      ;;
    down)
      RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
      CURRENT=$(printf '%s\n' "$RAW" | awk '/^Volume:/ {printf "%.0f", $2 * 100}')
      [[ "$CURRENT" =~ ^[0-9]+$ ]] || exit 0
      [ "$CURRENT" -le 0 ] && exit 0
      wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null || exit 0
      ;;
    mute)
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || exit 0
      ;;
    mic-mute)
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null || exit 0
      ;;
  esac
elif command -v pactl >/dev/null 2>&1; then
  case "$ACTION" in
    up)
      CURRENT=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk 'NR==1 && match($0, /[0-9]+%/) {print substr($0, RSTART, RLENGTH-1)}')
      [[ "$CURRENT" =~ ^[0-9]+$ ]] || exit 0
      if [ $((CURRENT + 5)) -ge 100 ]; then
        pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null || exit 0
      else
        pactl set-sink-volume @DEFAULT_SINK@ +5% 2>/dev/null || exit 0
      fi
      ;;
    down)
      pactl set-sink-volume @DEFAULT_SINK@ -5% 2>/dev/null || exit 0
      ;;
    mute)
      pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || exit 0
      ;;
    mic-mute)
      pactl set-source-mute @DEFAULT_SOURCE@ toggle 2>/dev/null || exit 0
      ;;
  esac
fi

# Volume and microphone feedback is rendered by IslandEventService. Do not
# also send notify-send OSDs, which would compete with the Dynamic Island.
