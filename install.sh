#!/usr/bin/env bash
# ==============================================================================
# Veyra Dotfiles — Safe, Idempotent Rice Installer (install.sh)
# Installs Veyra configs for Hyprland 0.57+ (Lua) & Quickshell with automatic
# timestamped backups, local preference preservation, template seeding, and
# post-install verification via doctor.sh.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# ------------------------------------------------------------------------------
# CLI Options & Defaults
# ------------------------------------------------------------------------------
DRY_RUN=0
ASSUME_YES=0
DEPS_MODE="auto"   # auto | install | skip
BACKUP_DIR=""
USE_COLOR=1
COLOR_FLAG=""

if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" || ! -t 1 ]]; then
    USE_COLOR=0
fi

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Safe, idempotent installer for Veyra Dotfiles (Hyprland 0.57+ Lua & Quickshell).

Options:
  -h, --help              Show this help message and exit
  -n, --dry-run           Preview all planned actions without modifying any files
  -y, --yes               Non-interactive mode (accept prompts automatically)
      --deps              Install Arch/CachyOS dependencies (pacman + paru/yay)
      --no-deps           Skip system package installation (never invokes sudo)
      --backup-dir <dir>  Custom backup directory
                          (default: ~/.local/share/veyra-backups/<timestamp>)
      --no-color          Disable ANSI color output
      --color             Force ANSI color output

Preserved User-Local Files (never overwritten on re-install):
  ~/.config/hypr/userprefs.local.lua
  ~/.config/hypr/monitors.lua
  ~/.config/hypr/veyra-settings.lua
  ~/.config/hypr/keybinds_custom.lua
  ~/.config/hypr/windowrules.local.lua
  ~/.config/quickshell/hotspot_backend.json
  ~/.local/share/veyra/todo.json
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -y|--yes)
            ASSUME_YES=1
            shift
            ;;
        --deps)
            DEPS_MODE="install"
            shift
            ;;
        --no-deps)
            DEPS_MODE="skip"
            shift
            ;;
        --backup-dir)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                printf 'Error: --backup-dir requires a directory argument.\n' >&2
                exit 2
            fi
            BACKUP_DIR="$2"
            shift 2
            ;;
        --backup-dir=*)
            BACKUP_DIR="${1#*=}"
            if [[ -z "$BACKUP_DIR" ]]; then
                printf 'Error: --backup-dir requires a non-empty directory argument.\n' >&2
                exit 2
            fi
            shift
            ;;
        --no-color)
            USE_COLOR=0
            COLOR_FLAG="--no-color"
            shift
            ;;
        --color)
            USE_COLOR=1
            COLOR_FLAG="--color"
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
# Colors & Logging Helpers
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

log_step() { printf '\n%s%s▸ %s%s\n' "$C_MAGENTA" "$C_BOLD" "$*" "$C_RESET"; }
log_info() { printf '  %s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_ok()   { printf '  %s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn() { printf '  %s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
log_err()  { printf '  %s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
log_dry()  { printf '  %s[DRY-RUN]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }

TMP_ITEMS=()
cleanup() {
    local p
    if (( ${#TMP_ITEMS[@]} > 0 )); then
        for p in "${TMP_ITEMS[@]}"; do
            [[ -n "$p" && -e "$p" ]] && rm -rf -- "$p"
        done
    fi
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Pre-flight & Path Resolution
# ------------------------------------------------------------------------------
CURRENT_UID="$(id -u)"
if [[ "$CURRENT_UID" -eq 0 ]]; then
    log_err "Do not run install.sh as root. Run as your regular user; sudo is requested only if --deps is used."
    exit 1
fi

REAL_HOME="$(getent passwd "$CURRENT_UID" 2>/dev/null | cut -d: -f6 || true)"
if [[ -z "$REAL_HOME" ]]; then
    REAL_HOME="$HOME"
fi

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

export XDG_CONFIG_HOME="$CONFIG_HOME"
export XDG_DATA_HOME="$DATA_HOME"
export XDG_STATE_HOME="$STATE_HOME"
export XDG_CACHE_HOME="$CACHE_HOME"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$DATA_HOME/veyra-backups/$TIMESTAMP"
fi

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

printf '\n%s%s╭──────────────────────────────────────────────────────────────────────────────╮%s\n' "$C_CYAN" "$C_BOLD" "$C_RESET"
printf '%s%s│  Veyra Dotfiles Installer — Hyprland 0.57+ (Lua) & Quickshell                │%s\n' "$C_CYAN" "$C_BOLD" "$C_RESET"
printf '%s%s╰──────────────────────────────────────────────────────────────────────────────╯%s\n' "$C_CYAN" "$C_BOLD" "$C_RESET"
printf '  %sSource repo:%s  %s\n' "$C_DIM" "$C_RESET" "$SCRIPT_DIR"
printf '  %sTarget HOME:%s  %s\n' "$C_DIM" "$C_RESET" "$HOME"
if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '  %sMode:%s         %sDRY-RUN (no filesystem changes or sudo calls)%s\n' \
        "$C_DIM" "$C_RESET" "$C_CYAN" "$C_RESET"
fi

log_step "Running pre-flight checks"

for req_dir in \
    "$SCRIPT_DIR/.config/hypr" \
    "$SCRIPT_DIR/.config/quickshell" \
    "$SCRIPT_DIR/.config/kitty" \
    "$SCRIPT_DIR/.config/fastfetch" \
    "$SCRIPT_DIR/.config/starship" \
    "$SCRIPT_DIR/.config/fish" \
    "$SCRIPT_DIR/.local/share/veyra"; do
    if [[ ! -d "$req_dir" ]]; then
        log_err "Repository directory missing: $req_dir"
        exit 1
    fi
done
log_ok "Verified Veyra repository source structure"

# Prevent accidental install over self if someone cloned directly into $HOME
if [[ "$(realpath -m -- "$SCRIPT_DIR")" == "$(realpath -m -- "$HOME")" ]]; then
    log_err "Repository root cannot be identical to \$HOME ($HOME). Clone into e.g. ~/dotfiles first."
    exit 1
fi

if [[ "$DRY_RUN" -eq 0 && "$ASSUME_YES" -eq 0 ]]; then
    if [[ ! -t 0 ]]; then
        log_err "Non-interactive shell detected without --yes (-y). Re-run with --yes or --dry-run."
        exit 1
    fi
    printf '\n  Proceed with installing Veyra configs into %s? [y/N] ' "$HOME"
    read -r reply
    if [[ ! "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        log_info "Installation cancelled by user."
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# Step 1: Optional Arch / CachyOS Dependency Installation
# ------------------------------------------------------------------------------
VEYRA_ALL_PACKAGES=(
    hyprland
    quickshell
    awww
    matugen
    python
    jq
    kitty
    fastfetch
    starship
    fish
    grim
    slurp
    wl-clipboard
    cliphist
    brightnessctl
    hypridle
    hyprsunset
    hyprpicker
    pipewire
    wireplumber
    sound-theme-freedesktop
    cava
    networkmanager
    bluez-utils
    ttf-jetbrains-mono-nerd
    otf-geist
    bibata-cursor-theme-bin
)

install_dependencies() {
    if ! command -v pacman >/dev/null 2>&1; then
        log_warn "pacman not detected — skipping automated Arch/CachyOS package installation."
        return 0
    fi

    local missing_pacman=()
    local missing_aur=()
    local pkg
    for pkg in "${VEYRA_ALL_PACKAGES[@]}"; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            continue
        fi
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            missing_pacman+=("$pkg")
        else
            missing_aur+=("$pkg")
        fi
    done

    if (( ${#missing_pacman[@]} == 0 && ${#missing_aur[@]} == 0 )); then
        log_ok "All ${#VEYRA_ALL_PACKAGES[@]} Veyra packages are already installed"
        return 0
    fi

    local aur_helper=""
    if command -v paru >/dev/null 2>&1; then
        aur_helper="paru"
    elif command -v yay >/dev/null 2>&1; then
        aur_helper="yay"
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        if (( ${#missing_pacman[@]} > 0 )); then
            log_dry "Would run: sudo pacman -S --needed ${missing_pacman[*]}"
        fi
        if (( ${#missing_aur[@]} > 0 )); then
            if [[ -n "$aur_helper" ]]; then
                log_dry "Would run: $aur_helper -S --needed ${missing_aur[*]}"
            else
                log_dry "Would advise installing AUR packages via paru/yay: ${missing_aur[*]}"
            fi
        fi
        return 0
    fi

    local noconfirm_flag=()
    if [[ "$ASSUME_YES" -eq 1 ]]; then
        noconfirm_flag=(--noconfirm)
    fi

    if (( ${#missing_pacman[@]} > 0 )); then
        log_info "Installing official repository packages (${#missing_pacman[@]}): ${missing_pacman[*]}"
        sudo pacman -S --needed "${noconfirm_flag[@]}" "${missing_pacman[@]}"
        log_ok "Official packages installed"
    fi

    if (( ${#missing_aur[@]} > 0 )); then
        if [[ -n "$aur_helper" ]]; then
            log_info "Installing AUR packages via $aur_helper (${#missing_aur[@]}): ${missing_aur[*]}"
            "$aur_helper" -S --needed "${noconfirm_flag[@]}" "${missing_aur[@]}"
            log_ok "AUR packages installed"
        else
            log_warn "No AUR helper (paru/yay) found. Install manually: paru -S --needed ${missing_aur[*]}"
        fi
    fi
}

log_step "Checking package dependencies"
case "$DEPS_MODE" in
    skip)
        log_info "Skipping system dependency installation (--no-deps)"
        ;;
    install)
        install_dependencies
        ;;
    auto)
        if [[ "$DRY_RUN" -eq 1 ]]; then
            install_dependencies
        elif [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
            log_info "Skipping system package installation in non-interactive mode (pass --deps to install packages)"
        elif command -v pacman >/dev/null 2>&1; then
            MISSING_COUNT=0
            for pkg in "${VEYRA_ALL_PACKAGES[@]}"; do
                if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
                    MISSING_COUNT=$((MISSING_COUNT + 1))
                fi
            done
            if (( MISSING_COUNT == 0 )); then
                log_ok "All ${#VEYRA_ALL_PACKAGES[@]} Veyra packages are already installed"
            else
                printf '  %d Veyra package(s) are not installed. Install now with pacman/AUR? [y/N] ' "$MISSING_COUNT"
                read -r dep_reply
                if [[ "$dep_reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
                    install_dependencies
                else
                    log_info "Skipped package installation (run ./install.sh --deps anytime)"
                fi
            fi
        else
            log_info "Non-Arch system detected; skipping pacman check"
        fi
        ;;
esac

# ------------------------------------------------------------------------------
# Step 2: Automatic Timestamped Backup of Existing Configs
# ------------------------------------------------------------------------------
log_step "Checking existing configuration for backup"

CONFIG_COMPONENTS=(hypr quickshell kitty fastfetch starship fish)
BACKUP_ITEMS=()

for comp in "${CONFIG_COMPONENTS[@]}"; do
    target="$CONFIG_HOME/$comp"
    if [[ -e "$target" || -L "$target" ]]; then
        BACKUP_ITEMS+=(".config/$comp::$target")
    fi
done

if [[ -e "$CONFIG_HOME/starship.toml" || -L "$CONFIG_HOME/starship.toml" ]]; then
    BACKUP_ITEMS+=(".config/starship.toml::$CONFIG_HOME/starship.toml")
fi

if [[ -e "$DATA_HOME/veyra" || -L "$DATA_HOME/veyra" ]]; then
    BACKUP_ITEMS+=(".local/share/veyra::$DATA_HOME/veyra")
fi

if (( ${#BACKUP_ITEMS[@]} == 0 )); then
    log_ok "Clean target environment — no pre-existing Veyra configs required backup"
else
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_dry "Would create backup directory: $(pretty_path "$BACKUP_DIR")"
        for entry in "${BACKUP_ITEMS[@]}"; do
            src_path="${entry#*::}"
            log_dry "Would back up $(pretty_path "$src_path") -> $(pretty_path "$BACKUP_DIR/${entry%%::*}")"
        done
    else
        mkdir -p -- "$BACKUP_DIR"
        for entry in "${BACKUP_ITEMS[@]}"; do
            rel_dest="${entry%%::*}"
            src_path="${entry#*::}"
            dest_path="$BACKUP_DIR/$rel_dest"
            mkdir -p -- "$(dirname -- "$dest_path")"
            cp -a -- "$src_path" "$dest_path"
        done
        log_ok "Backed up ${#BACKUP_ITEMS[@]} existing path(s) to $(pretty_path "$BACKUP_DIR")"
    fi
fi

# ------------------------------------------------------------------------------
# Step 3: Deploy Configs & Preserve User-Local Files
# ------------------------------------------------------------------------------
log_step "Deploying Veyra configurations"

# Relative paths (under target destination) that belong strictly to the local user
# or runtime theme generator and must never be overwritten from the repo checkout.
is_excluded_relpath() {
    local dom="$1"  # e.g. .config/hypr or .local/share/veyra
    local rel="$2"  # e.g. modules/keybinds.lua
    local base="${rel##*/}"

    # Universal exclusions: VCS, bytecode, editor/backup artifacts
    case "/$rel/" in
        */.git/*|*/__pycache__/*) return 0 ;;
    esac
    case "$base" in
        .git|.DS_Store|*.pyc|*.pyo|*.pyd|*.bak|*.bak*|*backup*|*.before-*)
            return 0
            ;;
    esac

    # Domain-specific user-local or machine-specific runtime files
    case "$dom/$rel" in
        .config/hypr/userprefs.local.lua|\
        .config/hypr/monitors.lua|\
        .config/hypr/veyra-settings.lua|\
        .config/hypr/keybinds_custom.lua|\
        .config/hypr/windowrules.local.lua|\
        .config/hypr/colors.local.lua|\
        .config/quickshell/hotspot_backend.json|\
        .config/kitty/theme.conf|\
        .config/fastfetch/themes/noctalia.jsonc|\
        .config/fish/fish_variables|\
        .local/share/veyra/todo.json|\
        .local/share/veyra/assets/*)
            return 0
            ;;
    esac

    return 1
}

sync_tree() {
    local dom="$1"
    local src_root="$2"
    local dst_root="$3"

    local copied=0
    if [[ "$DRY_RUN" -eq 1 ]]; then
        while IFS= read -r -d '' src_file; do
            local rel="${src_file#"$src_root"/}"
            if is_excluded_relpath "$dom" "$rel"; then
                continue
            fi
            copied=$((copied + 1))
        done < <(find "$src_root" \( -type f -o -type l \) -print0)
        log_dry "Would deploy $copied file(s) into $(pretty_path "$dst_root")"
        return 0
    fi

    # If target happened to be a symlink (e.g. previous GNU Stow setup), replace symlink with real directory
    if [[ -L "$dst_root" ]]; then
        rm -f -- "$dst_root"
    fi
    mkdir -p -- "$dst_root"

    while IFS= read -r -d '' src_file; do
        local rel="${src_file#"$src_root"/}"
        if is_excluded_relpath "$dom" "$rel"; then
            continue
        fi
        local dst_file="$dst_root/$rel"
        mkdir -p -- "$(dirname -- "$dst_file")"
        cp -dpf -- "$src_file" "$dst_file"
        copied=$((copied + 1))
    done < <(find "$src_root" \( -type f -o -type l \) -print0)

    log_ok "Deployed $(pretty_path "$dst_root") ($copied files)"
}

for comp in "${CONFIG_COMPONENTS[@]}"; do
    sync_tree ".config/$comp" "$SCRIPT_DIR/.config/$comp" "$CONFIG_HOME/$comp"
done
sync_tree ".local/share/veyra" "$SCRIPT_DIR/.local/share/veyra" "$DATA_HOME/veyra"

# Report preserved local files and seed .example templates when absent
log_step "Preserving user-local settings & seeding templates"

seed_or_preserve() {
    local target_file="$1"
    local example_file="$2"
    local label="$3"

    if [[ -f "$target_file" ]]; then
        log_ok "Preserved existing $label ($(pretty_path "$target_file"))"
    elif [[ -n "$example_file" && -f "$example_file" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log_dry "Would seed $(pretty_path "$target_file") from $(pretty_path "$example_file")"
        else
            mkdir -p -- "$(dirname -- "$target_file")"
            cp -p -- "$example_file" "$target_file"
            log_ok "Seeded $label -> $(pretty_path "$target_file")"
        fi
    fi
}

# Check example paths from target (or repo source during --dry-run on empty HOME)
USERPREFS_EXAMPLE="$CONFIG_HOME/hypr/examples/userprefs.local.lua.example"
[[ ! -f "$USERPREFS_EXAMPLE" ]] && USERPREFS_EXAMPLE="$SCRIPT_DIR/.config/hypr/examples/userprefs.local.lua.example"

HOTSPOT_EXAMPLE="$CONFIG_HOME/quickshell/hotspot_backend.json.example"
[[ ! -f "$HOTSPOT_EXAMPLE" ]] && HOTSPOT_EXAMPLE="$SCRIPT_DIR/.config/quickshell/hotspot_backend.json.example"

seed_or_preserve "$CONFIG_HOME/hypr/userprefs.local.lua" "$USERPREFS_EXAMPLE" "Hyprland local prefs"
seed_or_preserve "$CONFIG_HOME/quickshell/hotspot_backend.json" "$HOTSPOT_EXAMPLE" "Hotspot backend config"

for optional_local in \
    "$CONFIG_HOME/hypr/monitors.lua" \
    "$CONFIG_HOME/hypr/veyra-settings.lua" \
    "$CONFIG_HOME/hypr/keybinds_custom.lua" \
    "$CONFIG_HOME/hypr/windowrules.local.lua"; do
    if [[ -f "$optional_local" ]]; then
        log_ok "Preserved existing $(pretty_path "$optional_local")"
    fi
done

TODO_JSON="$DATA_HOME/veyra/todo.json"
if [[ -f "$TODO_JSON" ]]; then
    log_ok "Preserved existing $(pretty_path "$TODO_JSON")"
elif [[ "$DRY_RUN" -eq 1 ]]; then
    log_dry "Would initialize empty task list at $(pretty_path "$TODO_JSON")"
else
    mkdir -p -- "$(dirname -- "$TODO_JSON")"
    printf '[]\n' > "$TODO_JSON"
    chmod 600 -- "$TODO_JSON"
    log_ok "Initialized empty task list at $(pretty_path "$TODO_JSON")"
fi

# ------------------------------------------------------------------------------
# Step 4: Executable Permissions, Starship Symlink & Theme Generation
# ------------------------------------------------------------------------------
log_step "Finalizing permissions, symlinks & dynamic theme palette"

if [[ "$DRY_RUN" -eq 1 ]]; then
    log_dry "Would set chmod +x on helper scripts under ~/.config/{hypr,quickshell} and ~/.local/share/veyra"
    log_dry "Would link $(pretty_path "$CONFIG_HOME/starship.toml") -> starship/starship.toml"
else
    CHMOD_COUNT=0
    for sroot in "$CONFIG_HOME/hypr" "$CONFIG_HOME/quickshell" "$DATA_HOME/veyra"; do
        [[ ! -d "$sroot" ]] && continue
        while IFS= read -r -d '' sfile; do
            chmod +x -- "$sfile"
            CHMOD_COUNT=$((CHMOD_COUNT + 1))
        done < <(find "$sroot" -type f -name '*.sh' -print0)

        while IFS= read -r -d '' pyfile; do
            if head -c 2 -- "$pyfile" 2>/dev/null | grep -q '^#!'; then
                chmod +x -- "$pyfile"
                CHMOD_COUNT=$((CHMOD_COUNT + 1))
            fi
        done < <(find "$sroot" -type f -name '*.py' -print0)
    done
    log_ok "Ensured executable permissions on $CHMOD_COUNT script(s)"

    mkdir -p -- "$CONFIG_HOME"
    ln -sfn -- "starship/starship.toml" "$CONFIG_HOME/starship.toml"
    log_ok "Linked $(pretty_path "$CONFIG_HOME/starship.toml") -> starship/starship.toml"
fi

# Seed initial colorscheme.json when absent so apply_theme.py produces full palettes on fresh installs
STATE_COLORSCHEME="$STATE_HOME/veyra/colorscheme.json"
LEGACY_COLORSCHEME="$CACHE_HOME/quickshell/colorscheme.json"
DEFAULT_PRESET="$CONFIG_HOME/quickshell/theme-presets/orange-window.json"
[[ ! -f "$DEFAULT_PRESET" ]] && DEFAULT_PRESET="$SCRIPT_DIR/.config/quickshell/theme-presets/orange-window.json"

if [[ ! -s "$STATE_COLORSCHEME" && ! -s "$LEGACY_COLORSCHEME" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_dry "Would seed initial palette $(pretty_path "$STATE_COLORSCHEME") from default preset"
    else
        mkdir -p -- "$(dirname -- "$STATE_COLORSCHEME")"
        if [[ -s "$DEFAULT_PRESET" ]]; then
            cp -p -- "$DEFAULT_PRESET" "$STATE_COLORSCHEME"
        else
            cat > "$STATE_COLORSCHEME" <<'EOF'
{
  "name": "Veyra Default",
  "bg": "#080a0b",
  "fg": "#f0f2f4",
  "accent": "#65b2cc",
  "accentComplementary": "#6564cc"
}
EOF
        fi
        log_ok "Seeded initial colorscheme at $(pretty_path "$STATE_COLORSCHEME")"
    fi
fi

APPLY_THEME_PY="$CONFIG_HOME/quickshell/Scripts/theme/apply_theme.py"
if [[ "$DRY_RUN" -eq 1 ]]; then
    log_dry "Would run: python3 $(pretty_path "$APPLY_THEME_PY")"
elif command -v python3 >/dev/null 2>&1 && [[ -f "$APPLY_THEME_PY" ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" && "$HOME" == "$REAL_HOME" ]]; then
        if PYTHONDONTWRITEBYTECODE=1 python3 "$APPLY_THEME_PY" >/dev/null 2>&1; then
            log_ok "Applied Veyra dynamic theme across connected apps"
        else
            log_warn "apply_theme.py reported a non-fatal error; checking fallback palette files"
        fi
    else
        # Headless / TTY / isolated-HOME run: stub out live-session signaling binaries
        # so apply_theme.py writes all target config files cleanly without touching any
        # outer desktop session (hyprctl, pkill, gsettings, dbus-send, systemctl).
        SHIM_DIR="$(mktemp -d "${TMPDIR:-/tmp}/veyra-install-shims.XXXXXX")"
        TMP_ITEMS+=("$SHIM_DIR")
        for shim_cmd in hyprctl pkill gsettings dbus-send systemctl; do
            printf '#!/bin/sh\nexit 0\n' > "$SHIM_DIR/$shim_cmd"
            chmod +x -- "$SHIM_DIR/$shim_cmd"
        done

        if env \
            -u DISPLAY \
            -u WAYLAND_DISPLAY \
            -u HYPRLAND_INSTANCE_SIGNATURE \
            -u DBUS_SESSION_BUS_ADDRESS \
            VEYRA_SAFE_TEST=1 \
            PATH="$SHIM_DIR:$PATH" \
            HOME="$HOME" \
            XDG_CONFIG_HOME="$CONFIG_HOME" \
            XDG_DATA_HOME="$DATA_HOME" \
            XDG_STATE_HOME="$STATE_HOME" \
            XDG_CACHE_HOME="$CACHE_HOME" \
            PYTHONDONTWRITEBYTECODE=1 \
            python3 "$APPLY_THEME_PY" >/dev/null 2>&1; then
            log_ok "Generated initial Veyra theme palettes (headless-safe mode)"
        else
            log_warn "apply_theme.py encountered an issue in headless mode; applying static fallbacks"
        fi
    fi
else
    log_warn "python3 not found — seeding static fallback palette files"
fi

# Static fallback guarantee for generated files required at startup
if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ ! -s "$CONFIG_HOME/hypr/colors.local.lua" && -s "$CONFIG_HOME/hypr/colors.lua" ]]; then
        cp -p -- "$CONFIG_HOME/hypr/colors.lua" "$CONFIG_HOME/hypr/colors.local.lua"
        log_ok "Seeded fallback $(pretty_path "$CONFIG_HOME/hypr/colors.local.lua")"
    fi
    if [[ ! -s "$CONFIG_HOME/kitty/theme.conf" && -s "$CONFIG_HOME/kitty/themes/noctalia.conf" ]]; then
        cp -p -- "$CONFIG_HOME/kitty/themes/noctalia.conf" "$CONFIG_HOME/kitty/theme.conf"
        log_ok "Seeded fallback $(pretty_path "$CONFIG_HOME/kitty/theme.conf")"
    fi
fi

# ------------------------------------------------------------------------------
# Step 5: Run Veyra Doctor Verification
# ------------------------------------------------------------------------------
log_step "Running Veyra Doctor verification"

DOCTOR_SH="$SCRIPT_DIR/doctor.sh"
if [[ ! -x "$DOCTOR_SH" ]]; then
    log_warn "doctor.sh not found or not executable at $DOCTOR_SH"
elif [[ "$DRY_RUN" -eq 1 ]]; then
    log_dry "Would run: $DOCTOR_SH${COLOR_FLAG:+ $COLOR_FLAG}"
    printf '\n%s%s✓ Dry-run complete. Re-run ./install.sh without --dry-run to apply changes.%s\n\n' \
        "$C_GREEN" "$C_BOLD" "$C_RESET"
else
    DOCTOR_ARGS=()
    [[ -n "$COLOR_FLAG" ]] && DOCTOR_ARGS+=("$COLOR_FLAG")
    "$DOCTOR_SH" "${DOCTOR_ARGS[@]}"
fi
