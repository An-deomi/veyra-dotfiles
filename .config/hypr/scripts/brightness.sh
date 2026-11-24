#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

MIN_BRIGHTNESS=5

case "${1:-}" in
  up | down) ;;
  *)
    echo "Usage: brightness.sh {up|down}" >&2
    exit 2
    ;;
esac

if ! command -v brightnessctl >/dev/null 2>&1; then
  exit 0
fi

RAW=$(brightnessctl -m 2>/dev/null || true)
if [ -z "$RAW" ]; then
  # Desktop monitor or environment without a kernel backlight interface.
  exit 0
fi

CURRENT=$(printf '%s\n' "$RAW" | awk -F, 'NR==1 {gsub(/%/, "", $4); print $4}')
if ! [[ "$CURRENT" =~ ^[0-9]+$ ]]; then
  exit 0
fi

case "$1" in
  up)
    [ "$CURRENT" -ge 100 ] && exit 0
    brightnessctl -q set 5%+ 2>/dev/null || exit 0
    ;;
  down)
    if [ "$CURRENT" -le "$MIN_BRIGHTNESS" ]; then
      exit 0
    elif [ $((CURRENT - 5)) -lt "$MIN_BRIGHTNESS" ]; then
      brightnessctl -q set "${MIN_BRIGHTNESS}%" 2>/dev/null || exit 0
    else
      brightnessctl -q set 5%- 2>/dev/null || exit 0
    fi
    ;;
esac

# IslandEventService observes brightnessctl state and displays the new OSD.
# Avoid sending a second libnotify popup for the same adjustment.
