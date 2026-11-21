#!/bin/bash
set -euo pipefail

MIN_BRIGHTNESS=5
CURRENT=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%' || true)
if ! [[ "$CURRENT" =~ ^[0-9]+$ ]]; then
  CURRENT=100
fi

case "${1:-}" in
  up)
    [ "$CURRENT" -ge 100 ] && exit 0
    brightnessctl set 5%+
    ;;
  down)
    if [ "$CURRENT" -le "$MIN_BRIGHTNESS" ]; then
      exit 0
    elif [ $((CURRENT - 5)) -lt "$MIN_BRIGHTNESS" ]; then
      brightnessctl set "${MIN_BRIGHTNESS}%"
    else
      brightnessctl set 5%-
    fi
    ;;
  *)
    echo "Usage: brightness.sh {up|down}" >&2
    exit 2
    ;;
esac

# IslandEventService observes brightnessctl state and displays the new OSD.
# Avoid sending a second libnotify popup for the same adjustment.
