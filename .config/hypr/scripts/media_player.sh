#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
case "$ACTION" in
  play-pause | next | prev | stop) ;;
  *)
    echo "Usage: media_player.sh {play-pause|next|prev|stop}" >&2
    exit 2
    ;;
esac

if ! command -v playerctl >/dev/null 2>&1; then
  exit 0
fi

case "$ACTION" in
  play-pause)
    playerctl play-pause 2>/dev/null || true
    ;;
  next)
    playerctl next 2>/dev/null || true
    ;;
  prev)
    playerctl previous 2>/dev/null || true
    ;;
  stop)
    playerctl stop 2>/dev/null || true
    ;;
esac
