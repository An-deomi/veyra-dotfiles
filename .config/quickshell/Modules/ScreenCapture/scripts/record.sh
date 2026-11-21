#!/usr/bin/env bash

# Veyra screen recorder. Recording preferences are read from the same
# JSON file used by Quickshell SettingsService.
set -u

# Export essential environment variables for Wayland/Hyprland.
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$sock" ]; then
      export WAYLAND_DISPLAY=$(basename "$sock")
      break
    fi
  done
  export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
fi
export XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-Hyprland}

DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$DIR"
LOG="${XDG_RUNTIME_DIR:-/tmp}/veyra-record-${UID}.log"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
FILENAME="$DIR/Recording-${TIMESTAMP}.mkv"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_SCRIPT="$SCRIPT_DIR/record-control.sh"
STATE_FILE="$XDG_RUNTIME_DIR/veyra-wf-recorder-${UID}.state"

# A second invocation toggles the Veyra recording off. Do not kill unrelated
# wf-recorder processes that were started outside Veyra.
if [[ -x "$CONTROL_SCRIPT" ]]; then
  active_state=$("$CONTROL_SCRIPT" status 2>/dev/null || printf 'stopped')
  if [[ "$active_state" == "running" || "$active_state" == "paused" ]]; then
    "$CONTROL_SCRIPT" stop
    exit 0
  fi
fi
if pgrep -u "$UID" -x wf-recorder >/dev/null 2>&1; then
  echo "A wf-recorder process is already running but is not owned by Veyra." >>"$LOG"
  notify-send -i video-x-generic "Screen recording already running" "Stop the other wf-recorder session before starting another." 2>/dev/null || true
  exit 1
fi

echo "--- Record started at $(date) ---" >>"$LOG"

# Preferences live in the XDG state directory; the legacy cache location is
# still honoured when the state copy is absent (older installs, mid-migration).
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
PREFS_FILE="$STATE_HOME/veyra/settings_prefs.json"
[ -r "$PREFS_FILE" ] || PREFS_FILE="$CACHE_HOME/quickshell/settings_prefs.json"
AUDIO_MODE="output"
RECORD_RESOLUTION="source"
if command -v jq >/dev/null 2>&1 && [ -r "$PREFS_FILE" ]; then
  pref_audio=$(jq -r '.screenRecordAudioSource // empty' "$PREFS_FILE" 2>/dev/null || true)
  pref_resolution=$(jq -r '.screenRecordResolution // empty' "$PREFS_FILE" 2>/dev/null || true)
  case "$pref_audio" in none|output|input|both) AUDIO_MODE="$pref_audio" ;; esac
  case "$pref_resolution" in source|1080p|720p|480p) RECORD_RESOLUTION="$pref_resolution" ;; esac
fi

REGION=""
# Keep the existing ScreenCaptureContent.qml arguments compatible:
# -s was the old "include system audio" flag and is now just accepted;
# actual source choice comes from Settings -> Screen Capture. -r selects area.
while getopts "sr" opt; do
  case "$opt" in
    s) ;;
    r)
      GEOM=$(slurp 2>/dev/null)
      if [ -z "$GEOM" ]; then
        echo "Region selection canceled" >>"$LOG"
        exit 0
      fi
      REGION="$GEOM"
      ;;
    *) ;;
  esac
done

MIX_MODULE_IDS=()
RECORDER_PID=""
write_record_state() {
  local state="$1" tmp="${STATE_FILE}.tmp.$$"
  printf '%s %s\n' "$RECORDER_PID" "$state" >"$tmp" || return 1
  chmod 600 "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$STATE_FILE"
}
cleanup_audio_mix() {
  local idx state_pid
  if [[ -n "$RECORDER_PID" && -r "$STATE_FILE" ]]; then
    read -r state_pid _ <"$STATE_FILE" || state_pid=""
    if [[ "$state_pid" == "$RECORDER_PID" ]]; then
      rm -f -- "$STATE_FILE"
    fi
  fi
  rm -f -- "${STATE_FILE}.tmp.$$" 2>/dev/null || true
  for ((idx=${#MIX_MODULE_IDS[@]}-1; idx>=0; idx--)); do
    pactl unload-module "${MIX_MODULE_IDS[$idx]}" >/dev/null 2>&1 || true
  done
}
trap cleanup_audio_mix EXIT

source_exists() {
  local wanted="$1"
  pactl list short sources 2>/dev/null | awk -v wanted="$wanted" '$2 == wanted { found=1 } END { exit !found }'
}

get_output_monitor() {
  local sink source
  sink=$(pactl get-default-sink 2>/dev/null || true)
  if [ -z "$sink" ]; then
    sink=$(pactl info 2>/dev/null | sed -n 's/^Default Sink: //p' | head -n1)
  fi
  if [ -n "$sink" ]; then
    source="${sink}.monitor"
    if source_exists "$source"; then
      printf '%s' "$source"
      return 0
    fi
  fi
  pactl list short sources 2>/dev/null | awk '$2 ~ /\.monitor$/ { print $2; exit }'
}

get_input_source() {
  local source
  source=$(pactl get-default-source 2>/dev/null || true)
  if [ -n "$source" ] && [[ "$source" != *.monitor ]] && source_exists "$source"; then
    printf '%s' "$source"
    return 0
  fi
  pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/ { print $2; exit }'
}

load_audio_module() {
  local module_id
  module_id=$(pactl load-module "$@" 2>>"$LOG") || return 1
  [[ "$module_id" =~ ^[0-9]+$ ]] || return 1
  MIX_MODULE_IDS+=("$module_id")
}

recording_error() {
  local message="$1"
  echo "ERROR: $message" >>"$LOG"
  notify-send -i video-x-generic "Screen recording couldn't start" "$message" 2>/dev/null || true
  exit 1
}

AUDIO_SOURCE=""
case "$AUDIO_MODE" in
  none)
    ;;
  output)
    AUDIO_SOURCE=$(get_output_monitor)
    [ -n "$AUDIO_SOURCE" ] || recording_error "Couldn't find the default system-output monitor. Check PipeWire/PulseAudio."
    ;;
  input)
    AUDIO_SOURCE=$(get_input_source)
    [ -n "$AUDIO_SOURCE" ] || recording_error "Couldn't find a default microphone/input source. Check your audio devices."
    ;;
  both)
    OUTPUT_SOURCE=$(get_output_monitor)
    INPUT_SOURCE=$(get_input_source)
    [ -n "$OUTPUT_SOURCE" ] || recording_error "Couldn't find the system-output monitor needed to mix audio."
    [ -n "$INPUT_SOURCE" ] || recording_error "Couldn't find a microphone/input source needed to mix audio."
    command -v pactl >/dev/null 2>&1 || recording_error "pactl is required to mix microphone and system audio."
    MIX_SINK="veyra_record_mix_$$"
    load_audio_module module-null-sink "sink_name=$MIX_SINK" "sink_properties=device.description=VeyraRecordingMix" \
      || recording_error "Couldn't create the temporary audio-mix sink. Make sure PipeWire's PulseAudio compatibility is running."
    load_audio_module module-loopback "source=$OUTPUT_SOURCE" "sink=$MIX_SINK" "latency_msec=30" \
      || recording_error "Couldn't route system audio into the temporary mix."
    load_audio_module module-loopback "source=$INPUT_SOURCE" "sink=$MIX_SINK" "latency_msec=30" \
      || recording_error "Couldn't route microphone audio into the temporary mix."
    AUDIO_SOURCE="${MIX_SINK}.monitor"
    source_exists "$AUDIO_SOURCE" || recording_error "The temporary mixed audio source was not created correctly."
    ;;
esac

MONITOR=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor' 2>/dev/null || true)
if [ -z "$MONITOR" ] || [ "$MONITOR" = "null" ]; then
  MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null || true)
fi

echo "Recording monitor: $MONITOR | Region: $REGION | Audio mode: $AUDIO_MODE | Audio source: $AUDIO_SOURCE | Resolution cap: $RECORD_RESOLUTION | Output: $FILENAME" >>"$LOG"

CMD=("wf-recorder" "-x" "yuv420p" "-p" "color_range=tv" "-p" "color_primaries=bt709" "-p" "color_trc=bt709" "-p" "colorspace=bt709" "-c" "libx264" "-f" "$FILENAME")

# The chosen bounds are maximum dimensions: smaller displays are not upscaled,
# aspect ratio is preserved, and the result is forced to even dimensions for H.264.
case "$RECORD_RESOLUTION" in
  1080p) CMD+=("-F" "scale=w='min(iw,1920)':h='min(ih,1080)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
  720p)  CMD+=("-F" "scale=w='min(iw,1280)':h='min(ih,720)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
  480p)  CMD+=("-F" "scale=w='min(iw,854)':h='min(ih,480)':force_original_aspect_ratio=decrease:force_divisible_by=2") ;;
esac

if [ -n "$REGION" ]; then
  CMD+=("-g" "$REGION")
elif [ -n "$MONITOR" ]; then
  CMD+=("-o" "$MONITOR")
fi

if [ -n "$AUDIO_SOURCE" ]; then
  # Do not automatically unmute the user's microphone or change source privacy state.
  CMD+=("--audio=$AUDIO_SOURCE")
fi

# Run wf-recorder as a child so the HUD can pause, resume, and stop this
# exact recording. SIGINT is used for stop so wf-recorder can finalize the file.
"${CMD[@]}" >>"$LOG" 2>&1 &
RECORDER_PID=$!
# Wait briefly for the asynchronous child to exec the actual recorder before
# publishing its PID; otherwise an early status poll could mistake the short
# startup shell for an unrelated process and discard the state file.
for _ in {1..50}; do
  [[ -r "/proc/$RECORDER_PID/comm" ]] || break
  [[ "$(cat "/proc/$RECORDER_PID/comm" 2>/dev/null || true)" == "wf-recorder" ]] && break
  kill -0 "$RECORDER_PID" 2>/dev/null || break
  sleep 0.02
done
if [[ -r "/proc/$RECORDER_PID/comm" && "$(cat "/proc/$RECORDER_PID/comm" 2>/dev/null || true)" == "wf-recorder" ]]; then
  if ! write_record_state running; then
    echo "ERROR: could not write recorder state file $STATE_FILE" >>"$LOG"
    kill -INT "$RECORDER_PID" 2>/dev/null || true
  fi
else
  echo "ERROR: wf-recorder did not start as expected; control state not registered." >>"$LOG"
fi
wait "$RECORDER_PID"
RECORDER_STATUS=$?
if [ "$RECORDER_STATUS" -eq 0 ] && [ -f "$FILENAME" ]; then
  notify-send -i video-x-generic "Recording finished" "Saved to: $FILENAME"
else
  notify-send -i video-x-generic "Recording ended" "Check $LOG if the file is missing or incomplete." 2>/dev/null || true
fi
exit "$RECORDER_STATUS"
