#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v qs >/dev/null 2>&1; then
    echo "Error: Quickshell (qs) is not installed."
    exit 1
fi

ACTIVE_INSTANCES="$(qs list 2>/dev/null || true)"
if grep -q 'Process ID:' <<<"$ACTIVE_INSTANCES"; then
    echo "A Quickshell instance is already running."
    echo "$ACTIVE_INSTANCES"
    echo
    echo "Stop the current instance before testing to avoid overlapping bars."
    echo "Then rerun: $0"
    exit 2
fi

BASE="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
TEST_ROOT="$BASE/veyra-safe-test-${UID}-$$"
mkdir -m 700 -p "$TEST_ROOT/config" "$TEST_ROOT/cache/quickshell" \
    "$TEST_ROOT/data" "$TEST_ROOT/state"

CLIPHIST_WATCHER_PIDS=()

cleanup() {
    # Stop only the watchers created by this safe-test session. The user's
    # normal desktop clipboard watchers are left untouched.
    local pid
    for pid in "${CLIPHIST_WATCHER_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    for pid in "${CLIPHIST_WATCHER_PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

export XDG_CONFIG_HOME="$TEST_ROOT/config"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
export XDG_DATA_HOME="$TEST_ROOT/data"
export XDG_STATE_HOME="$TEST_ROOT/state"
export VEYRA_SAFE_TEST=1
export QS_NO_RELOAD_POPUP=1

# Start with harmless defaults. Preferences and theme cache remain temporary.
# SettingsService uses Quickshell SplitParser and parses one JSON object per
# emitted line. Keep this seed compact (single-line JSON), or each pretty-printed
# line will be treated as a separate invalid document.
cat <<'JSON' | tr -d '\n' > "$XDG_CACHE_HOME/quickshell/settings_prefs.json"
{
  "barStyle": "island",
  "adaptivePowerEnabled": false,
  "gameModeActive": false,
  "nightLightActive": false,
  "caffeineActive": false,
  "barMediaVisualizerEnabled": true,
  "desktopCavaEnabled": false,
  "musicPlayer": "all",
  "appThemeZenBrowserEnabled": false,
  "appThemeSpicetifyEnabled": false,
  "appThemeHeroicEnabled": false,
  "appThemePapirusEnabled": false,
  "appThemeTelegramEnabled": false,
  "appThemeVSCodiumEnabled": false,
  "dynamicThemeGtkEnabled": false,
  "dynamicThemeKColorSchemeEnabled": false,
  "dynamicThemeHyprlandEnabled": false,
  "dynamicThemeKittyEnabled": false,
  "dynamicThemeNeovimEnabled": false,
  "dynamicThemeQtEnabled": false,
  "dynamicThemeStarshipEnabled": false,
  "dynamicThemeBtopEnabled": false,
  "dynamicThemeLazygitEnabled": false,
  "dynamicThemeSvgAssetsEnabled": false
}
JSON
printf '\n' >> "$XDG_CACHE_HOME/quickshell/settings_prefs.json"

# Veyra's clipboard UI reads `cliphist list`, but the clipboard watchers in a
# normal desktop are usually started by the user's Hyprland/autostart config.
# Those watchers inherit the normal XDG_CACHE_HOME, while this test shell uses
# an isolated cache. Start test-owned watchers so V7 writes history into its
# own temporary cache rather than reading an empty database or touching the
# user's real clipboard history.
if command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1; then
    wl-paste --type text --watch cliphist store \
        >"$TEST_ROOT/cliphist-text-watcher.log" 2>&1 &
    CLIPHIST_WATCHER_PIDS+=("$!")
    wl-paste --type image --watch cliphist store \
        >"$TEST_ROOT/cliphist-image-watcher.log" 2>&1 &
    CLIPHIST_WATCHER_PIDS+=("$!")
    echo "- Clipboard history: isolated text/image watchers enabled; temporary history is deleted on exit."
else
    echo "- Clipboard history: unavailable (requires wl-paste and cliphist)."
fi

cat <<EOF
Starting Veyra in SAFE TEST mode.
- Existing Quickshell instance check: clear
- Settings/cache/state/data: temporary directory
- System font/cursor/power/Game Mode/theme/wallpaper/Hyprland writes: suppressed
- Exit with Ctrl+C; temporary files will be removed.
- Audio and brightness controls still operate on real hardware; avoid changing them in this test.

EOF

qs --path "$ROOT/shell.qml" --verbose
