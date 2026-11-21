#!/usr/bin/env bash
set -Eeuo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE_FILE="$XDG_RUNTIME_DIR/veyra-wf-recorder-$(id -u).state"
ACTION="${1:-status}"

read_state() {
  [[ -r "$STATE_FILE" ]] || return 1
  read -r PID STATUS < "$STATE_FILE" || return 1
  [[ "${PID:-}" =~ ^[0-9]+$ ]] || return 1
  [[ "${STATUS:-}" == running || "${STATUS:-}" == paused ]] || return 1
  [[ -r "/proc/$PID/comm" ]] || return 1
  [[ "$(cat "/proc/$PID/comm" 2>/dev/null || true)" == "wf-recorder" ]] || return 1
  local proc_state
  proc_state=$(awk '{print $3}' "/proc/$PID/stat" 2>/dev/null || true)
  [[ "$proc_state" != Z && "$proc_state" != X ]] || return 1
}

write_state() {
  local next="$1" tmp="${STATE_FILE}.tmp.$$"
  printf '%s %s\n' "$PID" "$next" > "$tmp"
  chmod 600 "$tmp"
  mv -f -- "$tmp" "$STATE_FILE"
  STATUS="$next"
}

if [[ "$ACTION" == status ]]; then
  if read_state; then
    printf '%s\n' "$STATUS"
  else
    rm -f -- "$STATE_FILE" "${STATE_FILE}.tmp."* 2>/dev/null || true
    printf 'stopped\n'
  fi
  exit 0
fi

if ! read_state; then
  printf 'No active Veyra recording found.\n' >&2
  exit 1
fi

case "$ACTION" in
  pause)
    if [[ "$STATUS" == paused ]]; then
      printf 'paused\n'
      exit 0
    fi
    kill -STOP "$PID"
    write_state paused
    printf 'paused\n'
    ;;
  resume)
    if [[ "$STATUS" == running ]]; then
      printf 'running\n'
      exit 0
    fi
    kill -CONT "$PID"
    write_state running
    printf 'running\n'
    ;;
  stop)
    # A stopped process cannot handle SIGINT until it is continued. SIGINT is
    # important here because wf-recorder uses it to finalize the video file.
    if [[ "$STATUS" == paused ]]; then
      kill -CONT "$PID"
      write_state running
      sleep 0.15
    fi
    kill -INT "$PID"
    printf 'stopping\n'
    ;;
  *)
    printf 'Usage: %s {status|pause|resume|stop}\n' "$0" >&2
    exit 2
    ;;
esac
