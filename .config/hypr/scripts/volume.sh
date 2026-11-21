#!/bin/bash
set -euo pipefail

case "${1:-}" in
  up)
    CURRENT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f", $2 * 100}')
    [ "$CURRENT" -ge 100 ] && exit 0
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0
    ;;
  down)
    CURRENT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f", $2 * 100}')
    [ "$CURRENT" -le 0 ] && exit 0
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    ;;
  mute)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    ;;
  mic-mute)
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    ;;
  *)
    echo "Usage: volume.sh {up|down|mute|mic-mute}" >&2
    exit 2
    ;;
esac

# Volume and microphone feedback is rendered by IslandEventService. Do not
# also send notify-send OSDs, which would compete with the Dynamic Island.
