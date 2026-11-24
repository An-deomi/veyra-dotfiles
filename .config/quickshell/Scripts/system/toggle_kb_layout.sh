#!/usr/bin/env bash

# Parse enabled layouts from Veyra settings (prefer XDG state dir, fall back to legacy cache)
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
PREFS_FILE="$STATE_HOME/veyra/settings_prefs.json"
if [ ! -f "$PREFS_FILE" ]; then
  PREFS_FILE="$CACHE_HOME/quickshell/settings_prefs.json"
fi

LAYOUTS_STR=""
if command -v jq >/dev/null 2>&1 && [ -f "$PREFS_FILE" ]; then
  LAYOUTS_STR=$(jq -r '.enabledKbLayouts | if type == "array" then join(" ") else empty end' "$PREFS_FILE" 2>/dev/null)
fi

if [ -z "$LAYOUTS_STR" ] || [ "$LAYOUTS_STR" = "null" ]; then
  LAYOUTS_STR="us latam" # Fallback
fi

read -r -a LAYOUTS <<<"$LAYOUTS_STR"
if [ "${#LAYOUTS[@]}" -eq 0 ]; then
  LAYOUTS=("us")
fi

if ! command -v hyprctl >/dev/null 2>&1; then
  exit 0
fi

# Get current layout from hyprland
CURRENT_LAYOUT=""
if command -v jq >/dev/null 2>&1; then
  CURRENT_LAYOUT=$(hyprctl getoption input:kb_layout -j 2>/dev/null | jq -r '.str // empty' 2>/dev/null | xargs)
fi

# Find index of current layout in the array
IDX=-1
for i in "${!LAYOUTS[@]}"; do
  # Support partial matching just in case (e.g. us* -> us)
  if [[ "$CURRENT_LAYOUT" == "${LAYOUTS[$i]}"* ]]; then
    IDX=$i
    break
  fi
done

# Calculate next index
NEXT_IDX=$(((IDX + 1) % ${#LAYOUTS[@]}))
NEW_LAYOUT="${LAYOUTS[$NEXT_IDX]}"

# Apply
hyprctl eval "hl.config({input = {kb_layout = '$NEW_LAYOUT'}})" 2>/dev/null || true
# IslandEventService handles activelayout events directly via Hyprland IPC.
