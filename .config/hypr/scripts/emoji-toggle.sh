#!/usr/bin/env bash
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME:-}/.config}"
DIR="$CONFIG_HOME/quickshell/emoji"

if [ ! -f "$DIR/shell.qml" ]; then
  exit 0
fi

QS_BIN=""
if command -v qs >/dev/null 2>&1; then
  QS_BIN="qs"
elif command -v quickshell >/dev/null 2>&1; then
  QS_BIN="quickshell"
else
  exit 0
fi

ESCAPED_DIR=$(printf '%s' "$DIR" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
if pkill -f -- "-p ${ESCAPED_DIR}$" 2>/dev/null; then
  exit 0
fi

exec "$QS_BIN" -p "$DIR"
