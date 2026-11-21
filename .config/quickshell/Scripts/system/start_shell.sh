#!/usr/bin/env bash
# Start the Veyra shell and prove it actually rendered.
#
# A single bad binding can make Quickshell load a config with zero surfaces:
# the process stays alive, the bar simply never appears, and the only clue is a
# line in stderr. This wrapper checks for real surfaces after startup and turns
# a silent failure into a visible notification.

set -uo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/veyra"
LOG="$STATE_DIR/shell-startup.log"
ATTEMPTS=24
INTERVAL=0.5

mkdir -p "$STATE_DIR"

if ! command -v qs >/dev/null 2>&1; then
    timeout 5 notify-send -u critical "Veyra: quickshell missing" "The 'qs' binary is not installed." 2>/dev/null || true
    exit 1
fi

# Already running? Nothing to supervise.
if pgrep -x qs >/dev/null 2>&1; then
    exit 0
fi

: >"$LOG"
setsid qs -p "$CONFIG_DIR" >>"$LOG" 2>&1 &

for _ in $(seq 1 "$ATTEMPTS"); do
    sleep "$INTERVAL"
    if ! pgrep -x qs >/dev/null 2>&1; then
        break
    fi
    if command -v hyprctl >/dev/null 2>&1 && hyprctl layers 2>/dev/null | grep -q quickshell; then
        exit 0
    fi
done

# Still alive but nothing on screen, or it died outright.
if pgrep -x qs >/dev/null 2>&1; then
    reason="started, but no surfaces were created"
else
    reason="exited during startup"
fi

summary=$(grep -aE "ERROR|Type .* unavailable|Property value set multiple times|syntax error" "$LOG" 2>/dev/null | tail -n 4)
if [ -z "$summary" ]; then
    summary="See $LOG"
fi

printf 'Veyra shell %s\n%s\n' "$reason" "$summary" >&2

# timeout: a missing notification daemon must not stall startup.
if command -v notify-send >/dev/null 2>&1; then
    timeout 5 notify-send -u critical -a Veyra "Veyra shell failed to start" "$reason
$summary" 2>/dev/null || true
fi

# Hyprland's own overlay, so the message survives a broken notification daemon.
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl notify 3 8000 "rgb(ff5555)" "Veyra shell $reason — see shell-startup.log" >/dev/null 2>&1 || true
fi

exit 1
