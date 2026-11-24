#!/usr/bin/env bash
# ==============================================================================
# Veyra Dotfiles — Rice Health & Connectivity Doctor (doctor.sh)
# Comprehensive diagnostics for Hyprland 0.57+ (Lua), Quickshell, theme engine,
# fonts/cursors, config wiring, portability, and runtime daemons.
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# CLI Options & Defaults
# ------------------------------------------------------------------------------
USE_COLOR=1
STRICT_MODE=0
JSON_MODE=0

if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" || ! -t 1 ]]; then
    USE_COLOR=0
fi

usage() {
    cat <<'EOF'
Usage: ./doctor.sh [OPTIONS]

Comprehensive health, dependency, wiring, and runtime doctor for the Veyra
Hyprland 0.57+ (Lua) + Quickshell desktop rice.

Options:
  -h, --help       Show this help message and exit
      --no-color   Disable ANSI color formatting
      --color      Force ANSI color formatting even when piped
      --strict     Treat warnings (WARN) as failures (exit code 1)
      --json       Emit structured JSON diagnostics report to stdout

Exit Codes:
  0  Healthy (no critical failures; and no warnings when --strict is set)
  1  Unhealthy (one or more critical checks failed, or warnings in --strict mode)
  2  Invalid command-line usage
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --no-color)
            USE_COLOR=0
            shift
            ;;
        --color)
            USE_COLOR=1
            shift
            ;;
        --strict)
            STRICT_MODE=1
            shift
            ;;
        --json)
            JSON_MODE=1
            USE_COLOR=0
            shift
            ;;
        *)
            printf 'Error: Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Colors & Formatting
# ------------------------------------------------------------------------------
if [[ "$USE_COLOR" -eq 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_GREEN=$'\033[38;5;78m'
    C_YELLOW=$'\033[38;5;221m'
    C_RED=$'\033[38;5;203m'
    C_CYAN=$'\033[38;5;117m'
    C_BLUE=$'\033[38;5;111m'
    C_MAGENTA=$'\033[38;5;183m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_CYAN=""
    C_BLUE=""
    C_MAGENTA=""
fi

# ------------------------------------------------------------------------------
# Environment & XDG Path Resolution
# ------------------------------------------------------------------------------
CURRENT_UID="$(id -u)"
CURRENT_USER="$(id -un 2>/dev/null || printf '%s' "${USER:-unknown}")"
REAL_HOME="$(getent passwd "$CURRENT_UID" 2>/dev/null | cut -d: -f6 || true)"
if [[ -z "$REAL_HOME" ]]; then
    REAL_HOME="$HOME"
fi

# When running against an isolated/sandboxed HOME (e.g. HOME=/tmp/...), ignore
# outer-session XDG_*_HOME variables that still point back to REAL_HOME.
resolve_xdg_dir() {
    local var_val="$1"
    local default_rel="$2"
    if [[ -n "$var_val" ]]; then
        if [[ "$HOME" != "$REAL_HOME" && "$var_val" == "$REAL_HOME"/* ]]; then
            printf '%s/%s' "${HOME%/}" "$default_rel"
            return
        fi
        printf '%s' "${var_val%/}"
    else
        printf '%s/%s' "${HOME%/}" "$default_rel"
    fi
}

CONFIG_HOME="$(resolve_xdg_dir "${XDG_CONFIG_HOME:-}" ".config")"
DATA_HOME="$(resolve_xdg_dir "${XDG_DATA_HOME:-}" ".local/share")"
STATE_HOME="$(resolve_xdg_dir "${XDG_STATE_HOME:-}" ".local/state")"
CACHE_HOME="$(resolve_xdg_dir "${XDG_CACHE_HOME:-}" ".cache")"

TMP_DIRS=()
cleanup() {
    local d
    if (( ${#TMP_DIRS[@]} > 0 )); then
        for d in "${TMP_DIRS[@]}"; do
            [[ -n "$d" && -e "$d" ]] && rm -rf -- "$d"
        done
    fi
}
trap cleanup EXIT

pretty_path() {
    local p="$1"
    if [[ "$p" == "$HOME"/* ]]; then
        printf '~/%s' "${p#"$HOME"/}"
    elif [[ "$p" == "$HOME" ]]; then
        printf '~'
    else
        printf '%s' "$p"
    fi
}

# Detect AUR helper for accurate remediation hints
AUR_HELPER="paru"
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

# ------------------------------------------------------------------------------
# Check Recording State
# ------------------------------------------------------------------------------
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

CHECK_CATEGORIES=()
CHECK_NAMES=()
CHECK_STATUSES=()
CHECK_DETAILS=()
CHECK_REMEDIES=()

PACMAN_MISSING=()
AUR_MISSING=()
OTHER_REMEDIES=()

add_unique() {
    local list_name="$1"
    local item="$2"
    [[ -z "$item" ]] && return 0
    local existing
    eval "local arr=(\"\${${list_name}[@]:-}\")"
    if (( ${#arr[@]} > 0 )); then
        for existing in "${arr[@]}"; do
            [[ "$existing" == "$item" ]] && return 0
        done
    fi
    eval "${list_name}+=(\"\$item\")"
}

record_check() {
    local category="$1"
    local name="$2"
    local status="$3"
    local detail="$4"
    local remedy="${5:-}"

    CHECK_CATEGORIES+=("$category")
    CHECK_NAMES+=("$name")
    CHECK_STATUSES+=("$status")
    CHECK_DETAILS+=("$detail")
    CHECK_REMEDIES+=("$remedy")

    case "$status" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        WARN)
            WARN_COUNT=$((WARN_COUNT + 1))
            [[ -n "$remedy" ]] && add_unique OTHER_REMEDIES "$remedy"
            ;;
        FAIL)
            FAIL_COUNT=$((FAIL_COUNT + 1))
            [[ -n "$remedy" ]] && add_unique OTHER_REMEDIES "$remedy"
            ;;
        SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
    esac
}

record_pkg_missing() {
    local pkg="$1"
    local is_aur="${2:-0}"
    if [[ "$is_aur" -eq 1 ]]; then
        add_unique AUR_MISSING "$pkg"
    elif command -v pacman >/dev/null 2>&1 && ! pacman -Si "$pkg" >/dev/null 2>&1; then
        add_unique AUR_MISSING "$pkg"
    else
        add_unique PACMAN_MISSING "$pkg"
    fi
}

check_binary() {
    local category="$1"
    local label="$2"
    local bin="$3"
    local pkg="$4"
    local severity="$5" # FAIL or WARN
    local is_aur="${6:-0}"

    local resolved=""
    if resolved="$(command -v "$bin" 2>/dev/null)"; then
        record_check "$category" "$label" "PASS" "$resolved" ""
    else
        record_pkg_missing "$pkg" "$is_aur"
        local hint="sudo pacman -S --needed $pkg"
        if [[ "$is_aur" -eq 1 ]]; then
            hint="$AUR_HELPER -S --needed $pkg"
        fi
        record_check "$category" "$label" "$severity" "Binary '$bin' not found in PATH" "$hint"
    fi
}

# ==============================================================================
# 1. Environment & Session
# ==============================================================================
CAT_ENV="Environment & Session"

OS_NAME="Unknown Linux"
OS_ID="unknown"
OS_ID_LIKE=""
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
fi
ARCH_NAME="$(uname -m 2>/dev/null || printf 'unknown')"
KERNEL_VER="$(uname -r 2>/dev/null || printf 'unknown')"

if [[ "$OS_ID" == "cachyos" || "$OS_ID" == "arch" || " $OS_ID_LIKE " == *" arch "* || -f /etc/arch-release ]]; then
    DISTRO_TAG="$OS_NAME ($ARCH_NAME, kernel $KERNEL_VER)"
    record_check "$CAT_ENV" "OS / Distribution" "PASS" "$DISTRO_TAG" ""
else
    record_check "$CAT_ENV" "OS / Distribution" "WARN" \
        "$OS_NAME ($ARCH_NAME) — package hints assume Arch Linux / CachyOS" ""
fi

IS_WAYLAND_LIVE=0
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    IS_WAYLAND_LIVE=1
    record_check "$CAT_ENV" "Wayland Session" "PASS" \
        "Active (${WAYLAND_DISPLAY}, session=${XDG_SESSION_TYPE:-wayland})" ""
else
    record_check "$CAT_ENV" "Wayland Session" "SKIP" \
        "Headless / TTY / CI environment (WAYLAND_DISPLAY unset)" ""
fi

HYPR_VERSION_RAW=""
if command -v Hyprland >/dev/null 2>&1; then
    HYPR_VERSION_RAW="$(Hyprland --version 2>/dev/null | head -n 1 || true)"
elif command -v hyprctl >/dev/null 2>&1; then
    HYPR_VERSION_RAW="$(hyprctl version 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$HYPR_VERSION_RAW" ]]; then
    record_pkg_missing "hyprland" 0
    record_check "$CAT_ENV" "Hyprland >= 0.57 (Lua)" "FAIL" \
        "Hyprland is not installed" "sudo pacman -S --needed hyprland"
else
    HYPR_VER="$(printf '%s' "$HYPR_VERSION_RAW" | sed -nE 's/.*Hyprland ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p')"
    if [[ -z "$HYPR_VER" ]]; then
        record_check "$CAT_ENV" "Hyprland >= 0.57 (Lua)" "WARN" \
            "Could not parse version from: $HYPR_VERSION_RAW" ""
    else
        IFS='.' read -r H_MAJ H_MIN _ <<< "$HYPR_VER"
        H_MAJ="${H_MAJ:-0}"
        H_MIN="${H_MIN:-0}"
        if (( H_MAJ > 0 || (H_MAJ == 0 && H_MIN >= 57) )); then
            LUA_DETAIL="Hyprland $HYPR_VER (native hyprland.lua config supported)"
            if [[ "$IS_WAYLAND_LIVE" -eq 1 && "$HOME" == "$REAL_HOME" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
                CFG_ERRS="$(hyprctl configerrors 2>/dev/null | sed '/^[[:space:]]*$/d' || true)"
                if [[ -z "$CFG_ERRS" ]]; then
                    LUA_DETAIL="Hyprland $HYPR_VER (native Lua active, 0 configerrors)"
                    record_check "$CAT_ENV" "Hyprland >= 0.57 (Lua)" "PASS" "$LUA_DETAIL" ""
                else
                    FIRST_ERR="$(printf '%s\n' "$CFG_ERRS" | head -n 1)"
                    record_check "$CAT_ENV" "Hyprland >= 0.57 (Lua)" "WARN" \
                        "Hyprland $HYPR_VER reports configerror: $FIRST_ERR" "hyprctl configerrors"
                fi
            else
                record_check "$CAT_ENV" "Hyprland >= 0.57 (Lua)" "PASS" "$LUA_DETAIL" ""
            fi
        else
            record_pkg_missing "hyprland" 0
            record_check "$CAT_ENV" "Hyprland >= 0.57 (Lua)" "FAIL" \
                "Found Hyprland $HYPR_VER; Veyra requires >= 0.57 for hyprland.lua" \
                "sudo pacman -Syu hyprland"
        fi
    fi
fi

# ==============================================================================
# 2. Required & Optional Binaries
# ==============================================================================
CAT_CORE_BIN="Core Binaries"

if command -v Hyprland >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1; then
    record_check "$CAT_CORE_BIN" "Hyprland / hyprctl" "PASS" \
        "$(command -v Hyprland), $(command -v hyprctl)" ""
else
    record_pkg_missing "hyprland" 0
    record_check "$CAT_CORE_BIN" "Hyprland / hyprctl" "FAIL" \
        "Missing Hyprland or hyprctl binary" "sudo pacman -S --needed hyprland"
fi

if command -v quickshell >/dev/null 2>&1; then
    QS_DETAIL="$(command -v quickshell)"
    if command -v qs >/dev/null 2>&1; then
        QS_DETAIL="$QS_DETAIL (qs: $(command -v qs))"
    fi
    record_check "$CAT_CORE_BIN" "quickshell" "PASS" "$QS_DETAIL" ""
elif command -v qs >/dev/null 2>&1; then
    record_check "$CAT_CORE_BIN" "quickshell" "PASS" "$(command -v qs)" ""
else
    record_pkg_missing "quickshell" 0
    record_check "$CAT_CORE_BIN" "quickshell" "FAIL" \
        "Binary 'quickshell' not found in PATH" "sudo pacman -S --needed quickshell"
fi

check_binary "$CAT_CORE_BIN" "awww"    "awww"    "awww"    "FAIL" 0
check_binary "$CAT_CORE_BIN" "matugen" "matugen" "matugen" "FAIL" 0
check_binary "$CAT_CORE_BIN" "python3" "python3" "python"  "FAIL" 0
check_binary "$CAT_CORE_BIN" "jq"      "jq"      "jq"      "FAIL" 0

CAT_RICE_BIN="Rice Apps"
check_binary "$CAT_RICE_BIN" "kitty"     "kitty"     "kitty"     "WARN" 0
check_binary "$CAT_RICE_BIN" "fastfetch" "fastfetch" "fastfetch" "WARN" 0
check_binary "$CAT_RICE_BIN" "starship"  "starship"  "starship"  "WARN" 0
check_binary "$CAT_RICE_BIN" "fish"      "fish"      "fish"      "WARN" 0

CAT_UTIL_BIN="Desktop Utilities"
check_binary "$CAT_UTIL_BIN" "grim"          "grim"          "grim"          "WARN" 0
check_binary "$CAT_UTIL_BIN" "slurp"         "slurp"         "slurp"         "WARN" 0

if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    record_check "$CAT_UTIL_BIN" "wl-clipboard" "PASS" \
        "$(command -v wl-copy), $(command -v wl-paste)" ""
else
    record_pkg_missing "wl-clipboard" 0
    record_check "$CAT_UTIL_BIN" "wl-clipboard" "WARN" \
        "wl-copy / wl-paste not found in PATH" "sudo pacman -S --needed wl-clipboard"
fi

check_binary "$CAT_UTIL_BIN" "cliphist"      "cliphist"      "cliphist"      "WARN" 0
check_binary "$CAT_UTIL_BIN" "brightnessctl" "brightnessctl" "brightnessctl" "WARN" 0
check_binary "$CAT_UTIL_BIN" "hypridle"      "hypridle"      "hypridle"      "WARN" 0
check_binary "$CAT_UTIL_BIN" "hyprsunset"    "hyprsunset"    "hyprsunset"    "WARN" 0
check_binary "$CAT_UTIL_BIN" "hyprpicker"    "hyprpicker"    "hyprpicker"    "WARN" 0
check_binary "$CAT_UTIL_BIN" "pw-play"       "pw-play"       "pipewire"      "WARN" 0
check_binary "$CAT_UTIL_BIN" "wpctl"         "wpctl"         "wireplumber"   "WARN" 0
check_binary "$CAT_UTIL_BIN" "cava"          "cava"          "cava"          "WARN" 0
check_binary "$CAT_UTIL_BIN" "nmcli"         "nmcli"         "networkmanager" "WARN" 0
check_binary "$CAT_UTIL_BIN" "bluetoothctl"  "bluetoothctl"  "bluez-utils"   "WARN" 0

# ==============================================================================
# 3. Fonts & Cursors
# ==============================================================================
CAT_ASSETS="Fonts & Cursors"

if command -v fc-list >/dev/null 2>&1; then
    FC_FAMILIES="$(fc-list : family 2>/dev/null || true)"
    if printf '%s\n' "$FC_FAMILIES" | grep -qiE '(^|,)Geist($|,| )'; then
        record_check "$CAT_ASSETS" "Font: Geist" "PASS" "Installed in fontconfig" ""
    else
        record_pkg_missing "otf-geist" 1
        record_check "$CAT_ASSETS" "Font: Geist" "WARN" \
            "Geist font family not found in fc-list" "$AUR_HELPER -S --needed otf-geist"
    fi

    if printf '%s\n' "$FC_FAMILIES" | grep -qiE 'JetBrainsMono (Nerd Font|NF)'; then
        record_check "$CAT_ASSETS" "Font: JetBrainsMono Nerd Font" "PASS" "Installed in fontconfig" ""
    else
        record_pkg_missing "ttf-jetbrains-mono-nerd" 0
        record_check "$CAT_ASSETS" "Font: JetBrainsMono Nerd Font" "WARN" \
            "JetBrainsMono Nerd Font not found in fc-list" "sudo pacman -S --needed ttf-jetbrains-mono-nerd"
    fi
else
    record_pkg_missing "fontconfig" 0
    record_check "$CAT_ASSETS" "Fontconfig (fc-list)" "WARN" \
        "fc-list not available to verify Geist & JetBrainsMono Nerd Font" \
        "sudo pacman -S --needed fontconfig"
fi

CURSOR_FOUND=""
for cursor_dir in \
    "$HOME/.icons/Bibata-Modern-Ice" \
    "$DATA_HOME/icons/Bibata-Modern-Ice" \
    "/usr/share/icons/Bibata-Modern-Ice"; do
    if [[ -d "$cursor_dir/cursors" || -f "$cursor_dir/index.theme" ]]; then
        CURSOR_FOUND="$cursor_dir"
        break
    fi
done

if [[ -n "$CURSOR_FOUND" ]]; then
    record_check "$CAT_ASSETS" "Cursor: Bibata-Modern-Ice" "PASS" "$(pretty_path "$CURSOR_FOUND")" ""
else
    record_pkg_missing "bibata-cursor-theme-bin" 1
    record_check "$CAT_ASSETS" "Cursor: Bibata-Modern-Ice" "WARN" \
        "Not found in ~/.icons, ~/.local/share/icons, or /usr/share/icons" \
        "$AUR_HELPER -S --needed bibata-cursor-theme-bin"
fi

# ==============================================================================
# 4. Config & Wiring Integrity
# ==============================================================================
CAT_CFG="Config & Wiring"

# 4a. Hyprland Lua entrypoint & modules
HYPR_LUA="$CONFIG_HOME/hypr/hyprland.lua"
if [[ -s "$HYPR_LUA" && -d "$CONFIG_HOME/hypr/modules" ]]; then
    MOD_COUNT="$(find "$CONFIG_HOME/hypr/modules" -maxdepth 1 -type f -name '*.lua' 2>/dev/null | wc -l | tr -d ' ')"
    record_check "$CAT_CFG" "Hyprland Lua config" "PASS" \
        "$(pretty_path "$HYPR_LUA") ($MOD_COUNT Lua modules)" ""
else
    record_check "$CAT_CFG" "Hyprland Lua config" "FAIL" \
        "Missing $(pretty_path "$HYPR_LUA") or modules/" "./install.sh"
fi

# 4b. User local prefs
USERPREFS_LOCAL="$CONFIG_HOME/hypr/userprefs.local.lua"
if [[ -f "$USERPREFS_LOCAL" ]]; then
    record_check "$CAT_CFG" "Hyprland local prefs" "PASS" "$(pretty_path "$USERPREFS_LOCAL")" ""
else
    record_check "$CAT_CFG" "Hyprland local prefs" "WARN" \
        "$(pretty_path "$USERPREFS_LOCAL") absent (using built-in defaults)" \
        "cp ~/.config/hypr/examples/userprefs.local.lua.example ~/.config/hypr/userprefs.local.lua"
fi

# 4c. GLSL Shaders directory
SHADERS_DIR="$CONFIG_HOME/hypr/shaders"
if [[ -d "$SHADERS_DIR" ]]; then
    SHADER_COUNT="$(find "$SHADERS_DIR" -maxdepth 1 -type f -name '*.glsl' 2>/dev/null | wc -l | tr -d ' ')"
    if (( SHADER_COUNT >= 4 )); then
        record_check "$CAT_CFG" "Hyprland GLSL shaders" "PASS" \
            "$(pretty_path "$SHADERS_DIR") ($SHADER_COUNT shaders)" ""
    elif (( SHADER_COUNT > 0 )); then
        record_check "$CAT_CFG" "Hyprland GLSL shaders" "WARN" \
            "Only $SHADER_COUNT shader(s) found in $(pretty_path "$SHADERS_DIR") (expected 4)" "./install.sh"
    else
        record_check "$CAT_CFG" "Hyprland GLSL shaders" "FAIL" \
            "No .glsl shaders found in $(pretty_path "$SHADERS_DIR")" "./install.sh"
    fi
else
    record_check "$CAT_CFG" "Hyprland GLSL shaders" "FAIL" \
        "Missing directory $(pretty_path "$SHADERS_DIR")" "./install.sh"
fi

# 4d. Quickshell root
QS_SHELL_QML="$CONFIG_HOME/quickshell/shell.qml"
if [[ -s "$QS_SHELL_QML" && -d "$CONFIG_HOME/quickshell/Core" && -d "$CONFIG_HOME/quickshell/Modules" ]]; then
    record_check "$CAT_CFG" "Quickshell shell.qml" "PASS" \
        "$(pretty_path "$QS_SHELL_QML") (+ Core/ & Modules/)" ""
else
    record_check "$CAT_CFG" "Quickshell shell.qml" "FAIL" \
        "Missing $(pretty_path "$QS_SHELL_QML") or Core/Modules directories" "./install.sh"
fi

# 4e. Starship config & symlink
STARSHIP_TARGET="$CONFIG_HOME/starship/starship.toml"
STARSHIP_LINK="$CONFIG_HOME/starship.toml"
if [[ ! -s "$STARSHIP_TARGET" ]]; then
    record_check "$CAT_CFG" "Starship symlink" "FAIL" \
        "Missing $(pretty_path "$STARSHIP_TARGET")" "./install.sh"
elif [[ -L "$STARSHIP_LINK" ]]; then
    RESOLVED_LINK="$(readlink -f "$STARSHIP_LINK" 2>/dev/null || true)"
    RESOLVED_TARGET="$(readlink -f "$STARSHIP_TARGET" 2>/dev/null || true)"
    if [[ -n "$RESOLVED_LINK" && "$RESOLVED_LINK" == "$RESOLVED_TARGET" ]]; then
        record_check "$CAT_CFG" "Starship symlink" "PASS" \
            "$(pretty_path "$STARSHIP_LINK") -> $(pretty_path "$STARSHIP_TARGET")" ""
    else
        record_check "$CAT_CFG" "Starship symlink" "FAIL" \
            "$(pretty_path "$STARSHIP_LINK") points to '${RESOLVED_LINK:-broken}' instead of $(pretty_path "$STARSHIP_TARGET")" \
            "ln -sfn starship/starship.toml ~/.config/starship.toml"
    fi
elif [[ -f "$STARSHIP_LINK" ]]; then
    record_check "$CAT_CFG" "Starship symlink" "WARN" \
        "$(pretty_path "$STARSHIP_LINK") is a regular file, not symlinked to $(pretty_path "$STARSHIP_TARGET")" \
        "ln -sfn starship/starship.toml ~/.config/starship.toml"
else
    record_check "$CAT_CFG" "Starship symlink" "FAIL" \
        "Missing symlink $(pretty_path "$STARSHIP_LINK") -> $(pretty_path "$STARSHIP_TARGET")" \
        "ln -sfn starship/starship.toml ~/.config/starship.toml"
fi

# 4f. Kitty config & theme.conf
KITTY_CONF="$CONFIG_HOME/kitty/kitty.conf"
KITTY_THEME="$CONFIG_HOME/kitty/theme.conf"
if [[ ! -s "$KITTY_CONF" ]]; then
    record_check "$CAT_CFG" "Kitty config & theme" "FAIL" \
        "Missing $(pretty_path "$KITTY_CONF")" "./install.sh"
elif [[ ! -s "$KITTY_THEME" ]]; then
    record_check "$CAT_CFG" "Kitty config & theme" "WARN" \
        "$(pretty_path "$KITTY_CONF") present, but $(pretty_path "$KITTY_THEME") not yet generated" \
        "python3 ~/.config/quickshell/Scripts/theme/apply_theme.py"
else
    record_check "$CAT_CFG" "Kitty config & theme" "PASS" \
        "$(pretty_path "$KITTY_CONF") + $(pretty_path "$KITTY_THEME")" ""
fi

# 4g. Fastfetch config.jsonc
FASTFETCH_CFG="$CONFIG_HOME/fastfetch/config.jsonc"
if [[ -s "$FASTFETCH_CFG" ]]; then
    record_check "$CAT_CFG" "Fastfetch config" "PASS" "$(pretty_path "$FASTFETCH_CFG")" ""
else
    record_check "$CAT_CFG" "Fastfetch config" "FAIL" \
        "Missing $(pretty_path "$FASTFETCH_CFG")" "./install.sh"
fi

# 4h. Veyra custom_templates & themed/sound assets
VEYRA_TEMPLATES="$DATA_HOME/veyra/custom_templates"
VEYRA_ASSETS="$DATA_HOME/veyra/assets"
QS_BUNDLED_ASSETS="$CONFIG_HOME/quickshell/assets"

if [[ -d "$VEYRA_TEMPLATES" ]]; then
    TPL_COUNT="$(find "$VEYRA_TEMPLATES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    record_check "$CAT_CFG" "Veyra custom templates" "PASS" \
        "$(pretty_path "$VEYRA_TEMPLATES") ($TPL_COUNT template packs)" ""
else
    record_check "$CAT_CFG" "Veyra custom templates" "FAIL" \
        "Missing $(pretty_path "$VEYRA_TEMPLATES")" "./install.sh"
fi

ASSET_DETAIL=""
SOUND_OK=0
if [[ -f /usr/share/sounds/freedesktop/stereo/complete.oga || -f /usr/share/sounds/ocean/stereo/outcome-success.oga ]]; then
    SOUND_OK=1
elif [[ -d "$VEYRA_ASSETS" ]] && compgen -G "$VEYRA_ASSETS/*.*" >/dev/null 2>&1; then
    if find "$VEYRA_ASSETS" -maxdepth 1 -type f \( -name '*.oga' -o -name '*.ogg' -o -name '*.wav' \) | grep -q .; then
        SOUND_OK=1
    fi
fi

if [[ -d "$VEYRA_ASSETS" ]]; then
    SVG_COUNT="$(find "$VEYRA_ASSETS" -maxdepth 1 -type f -name '*.svg' 2>/dev/null | wc -l | tr -d ' ')"
    ASSET_DETAIL="$(pretty_path "$VEYRA_ASSETS") ($SVG_COUNT themed SVGs)"
elif [[ -d "$QS_BUNDLED_ASSETS" ]]; then
    SVG_COUNT="$(find "$QS_BUNDLED_ASSETS" -maxdepth 1 -type f -name '*.svg' 2>/dev/null | wc -l | tr -d ' ')"
    ASSET_DETAIL="Fallback $(pretty_path "$QS_BUNDLED_ASSETS") ($SVG_COUNT bundled SVGs)"
fi

if [[ -n "$ASSET_DETAIL" && "$SOUND_OK" -eq 1 ]]; then
    record_check "$CAT_CFG" "Veyra & UI sound assets" "PASS" \
        "$ASSET_DETAIL + system stereo UI sounds" ""
elif [[ -n "$ASSET_DETAIL" && "$SOUND_OK" -eq 0 ]]; then
    record_pkg_missing "sound-theme-freedesktop" 0
    record_check "$CAT_CFG" "Veyra & UI sound assets" "WARN" \
        "$ASSET_DETAIL (freedesktop UI sound pack missing)" \
        "sudo pacman -S --needed sound-theme-freedesktop"
else
    record_check "$CAT_CFG" "Veyra & UI sound assets" "FAIL" \
        "Missing Veyra SVG icon assets" "./install.sh"
fi

# 4i. Hardcoded foreign /home/<other_user> path check
SCAN_ROOTS=()
for d in \
    "$CONFIG_HOME/hypr" \
    "$CONFIG_HOME/quickshell" \
    "$CONFIG_HOME/kitty" \
    "$CONFIG_HOME/fastfetch" \
    "$CONFIG_HOME/starship" \
    "$CONFIG_HOME/fish" \
    "$DATA_HOME/veyra"; do
    [[ -d "$d" ]] && SCAN_ROOTS+=("$d")
done

if (( ${#SCAN_ROOTS[@]} > 0 )); then
    FOREIGN_HITS=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        file_part="${line%%:*}"
        rest_part="${line#*:}"
        # Extract all /home/<user> tokens on the matched line
        while IFS= read -r match_path; do
            [[ -z "$match_path" ]] && continue
            matched_home="${match_path%/}"
            matched_user="${matched_home#/home/}"
            # Ignore generic documentation placeholders
            case "$matched_user" in
                user|username|you|your-user|your_user|example|alice|bob)
                    continue
                    ;;
            esac
            # Only allow exact match with active $HOME (so sandboxed HOME=/tmp/... catches /home/<author> leaks!)
            if [[ "$matched_home" != "${HOME%/}" ]]; then
                add_unique FOREIGN_HITS "$(pretty_path "$file_part") ($matched_home)"
            fi
        done < <(printf '%s\n' "$rest_part" | grep -oE '/home/[A-Za-z0-9._-]+/' || true)
    done < <(
        grep -rnI \
            --exclude-dir=.git \
            --exclude-dir=__pycache__ \
            --exclude-dir=docs \
            --exclude='*.bak*' \
            --exclude='*backup*' \
            --exclude='*.before-*' \
            --exclude='README*.md' \
            '/home/[A-Za-z0-9._-]\{1,\}/' "${SCAN_ROOTS[@]}" 2>/dev/null || true
    )

    if (( ${#FOREIGN_HITS[@]} == 0 )); then
        record_check "$CAT_CFG" "Portable paths check" "PASS" \
            "Zero foreign /home/<user> paths across active configs" ""
    else
        SAMPLE_HIT="${FOREIGN_HITS[0]}"
        record_check "$CAT_CFG" "Portable paths check" "FAIL" \
            "Found ${#FOREIGN_HITS[@]} file(s) with foreign /home path (e.g. $SAMPLE_HIT)" \
            "Replace hardcoded /home/<user> paths with \$HOME or XDG helpers"
    fi
else
    record_check "$CAT_CFG" "Portable paths check" "FAIL" \
        "No Veyra config directories found to scan" "./install.sh"
fi

# ==============================================================================
# 5. Theme Pipeline Health
# ==============================================================================
CAT_THEME="Theme Pipeline"
APPLY_THEME_PY="$CONFIG_HOME/quickshell/Scripts/theme/apply_theme.py"

if [[ ! -f "$APPLY_THEME_PY" ]]; then
    record_check "$CAT_THEME" "apply_theme.py compile" "FAIL" \
        "Missing $(pretty_path "$APPLY_THEME_PY")" "./install.sh"
elif command -v python3 >/dev/null 2>&1; then
    TMP_PYCACHE="$(mktemp -d "${TMPDIR:-/tmp}/veyra-doctor-pyc.XXXXXX")"
    TMP_DIRS+=("$TMP_PYCACHE")
    if PYTHONPYCACHEPREFIX="$TMP_PYCACHE" python3 -m py_compile "$APPLY_THEME_PY" >/dev/null 2>&1; then
        record_check "$CAT_THEME" "apply_theme.py compile" "PASS" \
            "py_compile succeeded ($(pretty_path "$APPLY_THEME_PY"))" ""
    else
        record_check "$CAT_THEME" "apply_theme.py compile" "FAIL" \
            "Syntax/compile error in $(pretty_path "$APPLY_THEME_PY")" \
            "python3 -m py_compile ~/.config/quickshell/Scripts/theme/apply_theme.py"
    fi
else
    record_check "$CAT_THEME" "apply_theme.py compile" "FAIL" \
        "python3 unavailable to compile apply_theme.py" "sudo pacman -S --needed python"
fi

STATE_COLORSCHEME="$STATE_HOME/veyra/colorscheme.json"
LEGACY_COLORSCHEME="$CACHE_HOME/quickshell/colorscheme.json"
HYPR_COLORS_LOCAL="$CONFIG_HOME/hypr/colors.local.lua"

ACTIVE_COLORSCHEME=""
if [[ -s "$STATE_COLORSCHEME" ]]; then
    ACTIVE_COLORSCHEME="$STATE_COLORSCHEME"
elif [[ -s "$LEGACY_COLORSCHEME" ]]; then
    ACTIVE_COLORSCHEME="$LEGACY_COLORSCHEME"
fi

MISSING_PALETTES=()
[[ -z "$ACTIVE_COLORSCHEME" ]] && MISSING_PALETTES+=("colorscheme.json")
[[ ! -s "$HYPR_COLORS_LOCAL" ]] && MISSING_PALETTES+=("hypr/colors.local.lua")
[[ ! -s "$KITTY_THEME" ]] && MISSING_PALETTES+=("kitty/theme.conf")
if [[ -f "$STARSHIP_TARGET" ]] && ! grep -q '^\[palettes\.quickshell\]' "$STARSHIP_TARGET" 2>/dev/null; then
    MISSING_PALETTES+=("starship [palettes.quickshell]")
fi

if (( ${#MISSING_PALETTES[@]} == 0 )); then
    record_check "$CAT_THEME" "Generated palette targets" "PASS" \
        "$(pretty_path "$ACTIVE_COLORSCHEME"), colors.local.lua, kitty/theme.conf, starship" ""
else
    JOINED_MISSING="$(IFS=', '; printf '%s' "${MISSING_PALETTES[*]}")"
    record_check "$CAT_THEME" "Generated palette targets" "WARN" \
        "Missing generated palette state: $JOINED_MISSING" \
        "python3 ~/.config/quickshell/Scripts/theme/apply_theme.py"
fi

# ==============================================================================
# 6. Live Daemon Status
# ==============================================================================
CAT_DAEMON="Live Daemons"

check_proc() {
    local label="$1"
    local pattern="$2"
    local mode="$3" # exact or full
    local start_hint="$4"
    local severity="${5:-WARN}"

    local pid=""
    if [[ "$mode" == "exact" ]]; then
        pid="$(pgrep -u "$CURRENT_UID" -x "$pattern" 2>/dev/null | head -n 1 || true)"
    else
        pid="$(pgrep -u "$CURRENT_UID" -f "$pattern" 2>/dev/null | head -n 1 || true)"
    fi

    if [[ -n "$pid" ]]; then
        record_check "$CAT_DAEMON" "$label" "PASS" "Running (PID $pid)" ""
    else
        record_check "$CAT_DAEMON" "$label" "$severity" "Not running in current session" "$start_hint"
    fi
}

if [[ "$IS_WAYLAND_LIVE" -eq 0 || "$HOME" != "$REAL_HOME" ]]; then
    SKIP_REASON="Headless / non-Wayland session — runtime daemon checks skipped"
    if [[ "$HOME" != "$REAL_HOME" ]]; then
        SKIP_REASON="Isolated HOME ($HOME) — host daemon checks skipped"
    fi
    record_check "$CAT_DAEMON" "Session daemons" "SKIP" "$SKIP_REASON" ""
else
    check_proc "Hyprland compositor" "Hyprland" "exact" "Start Hyprland from TTY or display manager" "FAIL"

    QS_PID="$(
        pgrep -u "$CURRENT_UID" -af '(^|/)(quickshell|qs)( |$)' 2>/dev/null \
            | grep -v 'hypr/alt-tab' \
            | awk 'NR==1 {print $1}' || true
    )"
    if [[ -n "$QS_PID" ]]; then
        record_check "$CAT_DAEMON" "Quickshell (Veyra bar)" "PASS" "Running (PID $QS_PID)" ""
    else
        record_check "$CAT_DAEMON" "Quickshell (Veyra bar)" "WARN" \
            "Not running in current session" "nohup qs -p ~/.config/quickshell >/dev/null 2>&1 &"
    fi

    check_proc "awww-daemon"      "awww-daemon"            "exact" "nohup awww-daemon >/dev/null 2>&1 &"
    check_proc "hypridle"         "hypridle"               "exact" "nohup hypridle >/dev/null 2>&1 &"
    check_proc "cliphist watcher" "wl-paste.*cliphist"     "full"  "wl-paste --type text --watch cliphist store &"
    check_proc "pipewire"         "pipewire"               "exact" "systemctl --user start pipewire.service"
fi

# ==============================================================================
# Determine Overall Exit Code
# ==============================================================================
EXIT_CODE=0
if (( FAIL_COUNT > 0 )); then
    EXIT_CODE=1
elif (( STRICT_MODE == 1 && WARN_COUNT > 0 )); then
    EXIT_CODE=1
fi

# Build consolidated package remediation commands
FINAL_REMEDIES=()
if (( ${#PACMAN_MISSING[@]} > 0 )); then
    FINAL_REMEDIES+=("sudo pacman -S --needed ${PACMAN_MISSING[*]}")
fi
if (( ${#AUR_MISSING[@]} > 0 )); then
    FINAL_REMEDIES+=("$AUR_HELPER -S --needed ${AUR_MISSING[*]}")
fi
if (( ${#OTHER_REMEDIES[@]} > 0 )); then
    for rem in "${OTHER_REMEDIES[@]}"; do
        # Skip individual package hints already covered by the grouped install commands
        if [[ "$rem" == "sudo pacman -S --needed "* || "$rem" == "$AUR_HELPER -S --needed "* ]]; then
            continue
        fi
        add_unique FINAL_REMEDIES "$rem"
    done
fi

# ==============================================================================
# Output: JSON or Formatted Table
# ==============================================================================
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

if [[ "$JSON_MODE" -eq 1 ]]; then
    HEALTHY_BOOL="false"
    [[ "$EXIT_CODE" -eq 0 ]] && HEALTHY_BOOL="true"

    printf '{\n'
    printf '  "healthy": %s,\n' "$HEALTHY_BOOL"
    printf '  "strict": %s,\n' "$( (( STRICT_MODE == 1 )) && printf 'true' || printf 'false' )"
    printf '  "exit_code": %d,\n' "$EXIT_CODE"
    printf '  "environment": {\n'
    printf '    "user": "%s",\n' "$(json_escape "$CURRENT_USER")"
    printf '    "home": "%s",\n' "$(json_escape "$HOME")"
    printf '    "config_home": "%s",\n' "$(json_escape "$CONFIG_HOME")"
    printf '    "os": "%s",\n' "$(json_escape "$OS_NAME")"
    printf '    "arch": "%s",\n' "$(json_escape "$ARCH_NAME")"
    printf '    "wayland_display": "%s"\n' "$(json_escape "${WAYLAND_DISPLAY:-}")"
    printf '  },\n'
    printf '  "summary": {\n'
    printf '    "pass": %d,\n' "$PASS_COUNT"
    printf '    "warn": %d,\n' "$WARN_COUNT"
    printf '    "fail": %d,\n' "$FAIL_COUNT"
    printf '    "skip": %d,\n' "$SKIP_COUNT"
    printf '    "total": %d\n' "${#CHECK_NAMES[@]}"
    printf '  },\n'
    printf '  "checks": [\n'
    for (( i = 0; i < ${#CHECK_NAMES[@]}; i++ )); do
        comma=","
        (( i == ${#CHECK_NAMES[@]} - 1 )) && comma=""
        printf '    {"category": "%s", "name": "%s", "status": "%s", "detail": "%s", "remedy": "%s"}%s\n' \
            "$(json_escape "${CHECK_CATEGORIES[$i]}")" \
            "$(json_escape "${CHECK_NAMES[$i]}")" \
            "$(json_escape "${CHECK_STATUSES[$i]}")" \
            "$(json_escape "${CHECK_DETAILS[$i]}")" \
            "$(json_escape "${CHECK_REMEDIES[$i]}")" \
            "$comma"
    done
    printf '  ],\n'
    printf '  "remediations": ['
    if (( ${#FINAL_REMEDIES[@]} > 0 )); then
        printf '\n'
        for (( i = 0; i < ${#FINAL_REMEDIES[@]}; i++ )); do
            comma=","
            (( i == ${#FINAL_REMEDIES[@]} - 1 )) && comma=""
            printf '    "%s"%s\n' "$(json_escape "${FINAL_REMEDIES[$i]}")" "$comma"
        done
        printf '  ]\n'
    else
        printf ']\n'
    fi
    printf '}\n'
    exit "$EXIT_CODE"
fi

# Human-readable table output
printf '\n%s%s╭──────────────────────────────────────────────────────────────────────────────╮%s\n' "$C_CYAN" "$C_BOLD" "$C_RESET"
printf '%s%s│  Veyra Rice Doctor — Health & Connectivity Diagnostics                       │%s\n' "$C_CYAN" "$C_BOLD" "$C_RESET"
printf '%s%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n' "$C_CYAN" "$C_BOLD" "$C_RESET"
printf '  %sTarget HOME:%s %s   %sConfig:%s %s\n' \
    "$C_DIM" "$C_RESET" "$HOME" "$C_DIM" "$C_RESET" "$(pretty_path "$CONFIG_HOME")"

LAST_CAT=""
for (( i = 0; i < ${#CHECK_NAMES[@]}; i++ )); do
    cat_name="${CHECK_CATEGORIES[$i]}"
    item_name="${CHECK_NAMES[$i]}"
    status="${CHECK_STATUSES[$i]}"
    detail="${CHECK_DETAILS[$i]}"

    if [[ "$cat_name" != "$LAST_CAT" ]]; then
        printf '\n%s%s▸ %s%s\n' "$C_MAGENTA" "$C_BOLD" "$cat_name" "$C_RESET"
        LAST_CAT="$cat_name"
    fi

    case "$status" in
        PASS) badge="${C_GREEN}${C_BOLD}[PASS]${C_RESET}" ;;
        WARN) badge="${C_YELLOW}${C_BOLD}[WARN]${C_RESET}" ;;
        FAIL) badge="${C_RED}${C_BOLD}[FAIL]${C_RESET}" ;;
        SKIP) badge="${C_BLUE}${C_BOLD}[SKIP]${C_RESET}" ;;
        *)    badge="[${status}]" ;;
    esac

    printf '  %s  %-30s %s%s%s\n' "$badge" "$item_name" "$C_DIM" "$detail" "$C_RESET"
done

printf '\n%s────────────────────────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"
printf '  %sSummary:%s  %s%d PASS%s  │  %s%d WARN%s  │  %s%d FAIL%s  │  %s%d SKIP%s\n' \
    "$C_BOLD" "$C_RESET" \
    "$C_GREEN" "$PASS_COUNT" "$C_RESET" \
    "$C_YELLOW" "$WARN_COUNT" "$C_RESET" \
    "$C_RED" "$FAIL_COUNT" "$C_RESET" \
    "$C_BLUE" "$SKIP_COUNT" "$C_RESET"
printf '%s────────────────────────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"

if (( ${#FINAL_REMEDIES[@]} > 0 )); then
    printf '\n%s%sSuggested Remediations:%s\n' "$C_YELLOW" "$C_BOLD" "$C_RESET"
    for rem in "${FINAL_REMEDIES[@]}"; do
        printf '  %s$%s %s\n' "$C_CYAN" "$C_RESET" "$rem"
    done
fi

if [[ "$EXIT_CODE" -eq 0 ]]; then
    if (( WARN_COUNT > 0 )); then
        printf '\n%s%s✓ Veyra core health checks passed with %d non-critical warning(s).%s\n\n' \
            "$C_GREEN" "$C_BOLD" "$WARN_COUNT" "$C_RESET"
    else
        printf '\n%s%s✓ All Veyra health & connectivity checks passed!%s\n\n' \
            "$C_GREEN" "$C_BOLD" "$C_RESET"
    fi
else
    if (( FAIL_COUNT > 0 )); then
        printf '\n%s%s✗ Veyra doctor detected %d critical failure(s). Run the commands above to fix.%s\n\n' \
            "$C_RED" "$C_BOLD" "$FAIL_COUNT" "$C_RESET"
    else
        printf '\n%s%s✗ Veyra doctor exited non-zero under --strict (%d warning(s)).%s\n\n' \
            "$C_RED" "$C_BOLD" "$WARN_COUNT" "$C_RESET"
    fi
fi

exit "$EXIT_CODE"
