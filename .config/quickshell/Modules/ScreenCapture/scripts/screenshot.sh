#!/bin/bash

# Export essential environment variables for Wayland/Hyprland
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
if [ -z "$WAYLAND_DISPLAY" ]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$sock" ]; then
      export WAYLAND_DISPLAY=$(basename "$sock")
      break
    fi
  done
  export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
fi
export XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-Hyprland}

MODE="${1:-full}"
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
FILENAME="$DIR/Shot-${TIMESTAMP}.png"

# Grim supports -c/--cursor for screenshots. This preference only affects
# still images; wf-recorder has no per-recording cursor switch.
# Preferences live in the XDG state directory; the legacy cache location is
# still honoured when the state copy is absent (older installs, mid-migration).
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
PREFS_FILE="$STATE_HOME/veyra/settings_prefs.json"
[ -r "$PREFS_FILE" ] || PREFS_FILE="$CACHE_HOME/quickshell/settings_prefs.json"
INCLUDE_CURSOR="false"
UI_SOUNDS="true"
if command -v jq >/dev/null 2>&1 && [ -r "$PREFS_FILE" ]; then
  cursor_pref=$(jq -r '.screenCaptureIncludeCursor // false' "$PREFS_FILE" 2>/dev/null || printf 'false')
  case "$cursor_pref" in true) INCLUDE_CURSOR="true" ;; esac
  sound_pref=$(jq -r 'if .uiSoundsEnabled == false then "false" else "true" end' "$PREFS_FILE" 2>/dev/null || printf 'true')
  case "$sound_pref" in false) UI_SOUNDS="false" ;; esac
fi
GRIM_CURSOR_ARGS=()
if [ "$INCLUDE_CURSOR" = "true" ]; then
  GRIM_CURSOR_ARGS=(-c)
fi

mkdir -p "$DIR"

# Ensure any dangling slurp instance is terminated
pkill -x slurp 2>/dev/null

play_sound() {
  [ "$UI_SOUNDS" = "true" ] || return 0
  local sound="/usr/share/sounds/freedesktop/stereo/screen-capture.oga"
  if [ -f "$sound" ]; then
    if command -v paplay &>/dev/null; then
      paplay "$sound" >/dev/null 2>&1 &
    elif command -v pw-play &>/dev/null; then
      pw-play "$sound" >/dev/null 2>&1 &
    fi
  fi
}

copy_and_notify() {
  if [ -f "$FILENAME" ]; then
    if command -v wl-copy &>/dev/null; then
      wl-copy <"$FILENAME"
    fi
    play_sound
  fi
}

if ! command -v grim &>/dev/null; then
  notify-send -u critical "Screenshot failed" "grim is not installed." 2>/dev/null || true
  exit 1
fi

take_screenshot() {
  local target_mode="$1"

  case "$target_mode" in
  "full")
    sleep 0.3
    grim "${GRIM_CURSOR_ARGS[@]}" "$FILENAME" || return 1
    ;;

  "area" | "select")
    local geom
    geom=$(slurp -d 2>/dev/null)
    if [ -z "$geom" ]; then
      return 1
    fi
    sleep 0.2
    grim "${GRIM_CURSOR_ARGS[@]}" -g "$geom" "$FILENAME" || return 1
    ;;

  "window")
    sleep 0.3
    local raw_json win_w win_h geom rounding
    raw_json=$(hyprctl activewindow -j 2>/dev/null)
    geom=$(echo "$raw_json" | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)
    win_w=$(echo "$raw_json" | jq -r '.size[0]' 2>/dev/null)
    win_h=$(echo "$raw_json" | jq -r '.size[1]' 2>/dev/null)

    if [ -z "$geom" ] || [ "$geom" = "null" ] || [ -z "$win_w" ] || [ "$win_w" -le 0 ]; then
      return 1
    fi

    grim "${GRIM_CURSOR_ARGS[@]}" -g "$geom" "$FILENAME" || return 1

    rounding=$(hyprctl getoption decoration:rounding 2>/dev/null | awk '/int:/ {print $2}')
    rounding=${rounding:-10}

    local conv_cmd="convert"
    if command -v magick &>/dev/null; then
      conv_cmd="magick"
    fi

    if command -v "$conv_cmd" &>/dev/null; then
      "$conv_cmd" "$FILENAME" \
        \( +clone \
        -alpha extract \
        -fill black -colorize 100 \
        -fill white \
        -draw "roundrectangle 0,0 $((win_w - 1)),$((win_h - 1)) ${rounding},${rounding}" \
        \) \
        -alpha off \
        -compose CopyOpacity \
        -composite \
        PNG32:"$FILENAME" 2>/dev/null || true
    fi
    ;;

  *)
    return 1
    ;;
  esac

  return 0
}

case "$MODE" in
"area_3s" | "3s" | "area_delay")
  delay=3
  if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
    delay="$2"
  fi
  sleep "$delay"
  if take_screenshot "area"; then
    copy_and_notify
  fi
  ;;

"full_3s" | "full_delay" | "5s")
  delay=3
  if [ "$MODE" = "5s" ]; then
    delay=5
  elif [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
    delay="$2"
  fi
  sleep "$delay"
  if take_screenshot "full"; then
    copy_and_notify
  fi
  ;;

"clipboard")
  command -v slurp &>/dev/null || { notify-send -u critical "Screenshot failed" "slurp is not installed." 2>/dev/null || true; exit 1; }
  geom=$(slurp -d 2>/dev/null)
  if [ -n "$geom" ]; then
    sleep 0.2
    if command -v wl-copy &>/dev/null; then
      grim "${GRIM_CURSOR_ARGS[@]}" -g "$geom" - | wl-copy --type image/png
      play_sound
    fi
  fi
  ;;

"ocr")
  if ! command -v slurp &>/dev/null || ! command -v tesseract &>/dev/null; then
    notify-send -u critical "OCR failed" "Install slurp and tesseract first." 2>/dev/null || true
    exit 1
  fi
  geom=$(slurp -d 2>/dev/null)
  if [ -n "$geom" ]; then
    sleep 0.2
    temp_ocr=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/veyra-ocr-XXXXXX.png")
    grim "${GRIM_CURSOR_ARGS[@]}" -g "$geom" "$temp_ocr" 2>/dev/null
    if [ -f "$temp_ocr" ]; then
      ocr_langs="eng"
      if tesseract --list-langs 2>/dev/null | grep -qx "ara"; then
        ocr_langs="eng+ara"
      fi
      if ocr_text=$(tesseract "$temp_ocr" stdout -l "$ocr_langs" 2>/dev/null || tesseract "$temp_ocr" stdout 2>/dev/null); then
        if command -v wl-copy &>/dev/null; then
          printf '%s' "$ocr_text" | wl-copy
        fi
        notify-send -r 699 "Screenshot" "Text extracted and copied to clipboard" 2>/dev/null || true
        play_sound
      else
        notify-send -u critical "OCR failed" "Could not extract text (check tesseract language data)." 2>/dev/null || true
      fi
    fi
    rm -f "$temp_ocr"
  fi
  ;;

*)
  if take_screenshot "$MODE"; then
    copy_and_notify
  fi
  ;;
esac
