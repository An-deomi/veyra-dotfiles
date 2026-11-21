#!/usr/bin/env python3
"""Veyra-managed app theme templates. No Noctalia runtime is required."""
from __future__ import annotations
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from xdg_paths import config_home, data_home, cache_home, state_home

PLACEHOLDER = re.compile(r"\{\{\s*colors\.([A-Za-z0-9_]+)\.(default|dark|light)\.(hex_stripped|hex)\s*\}\}")
SETTING_KEYS = {
    "zen-browser": "appThemeZenBrowserEnabled",
    "spicetify": "appThemeSpicetifyEnabled",
    "heroiclauncher": "appThemeHeroicEnabled",
    "papirus-icons": "appThemePapirusEnabled",
    "telegram": "appThemeTelegramEnabled",
    "vscodium": "appThemeVSCodiumEnabled",
}
ALIASES = {
    "source_color": ("accent",),
    "background": ("bg", "opaqueBg"),
    "on_background": ("fg",),
    "on_surface": ("fg",),
    "on_surface_variant": ("muted", "fg"),
    "surface": ("opaqueBg", "bg"),
    "surface_variant": ("bgSecondary", "bg"),
    "outline": ("border", "muted"),
    "outline_variant": ("border", "muted"),
    "shadow": ("shadow", "bg"),
}
ZEN_BEGIN = "/* VEYRA APP THEMES: ZEN BEGIN */"
ZEN_END = "/* VEYRA APP THEMES: ZEN END */"
USERJS_BEGIN = "// VEYRA APP THEMES: ZEN BEGIN"
USERJS_END = "// VEYRA APP THEMES: ZEN END"


def _paths(home):
    home = Path(home).expanduser()
    config_root = config_home(home)
    cache_root = cache_home(home)
    state_root = state_home(home)
    state = state_root / "veyra-app-themes/manager"
    return {
        "home": home,
        "templates": config_root / "quickshell/Scripts/theme/app_templates",
        "cache": cache_root / "quickshell/app-themes",
        "state": state,
        "originals": state / "originals",
        "active": state / "active",
        "prefs": state_root / "veyra/settings_prefs.json",
    }


def _load_preferences(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def _write_text(path, text):
    # Veyra optimization: avoid rewriting identical theme files.
    try:
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as current_file:
                if current_file.read() == text:
                    return
    except (OSError, UnicodeError, TypeError):
        pass
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    if path.is_file():
        try:
            if path.read_text(encoding="utf-8") == text:
                return
        except (OSError, UnicodeError):
            pass

    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".veyra-tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def _write_text_in_place(path, text):
    # Veyra optimization: avoid rewriting identical theme files.
    try:
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as current_file:
                if current_file.read() == text:
                    return
    except (OSError, UnicodeError, TypeError):
        pass
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    if path.is_file():
        try:
            if path.read_text(encoding="utf-8") == text:
                return
        except (OSError, UnicodeError):
            pass

    with path.open("w", encoding="utf-8") as handle:
        handle.write(text)


def _atomic_json(path, value):
    _write_text(path, json.dumps(value, indent=2, sort_keys=True) + "\n")


def _active_file(paths, app):
    return paths["active"] / (app + ".json")


def _is_active(paths, app):
    return _active_file(paths, app).exists()


def _set_active(paths, app, active):
    marker = _active_file(paths, app)
    if active:
        _atomic_json(marker, {"active": True})
    else:
        try:
            marker.unlink()
        except FileNotFoundError:
            pass


def _file_record(paths, app, target):
    target = Path(target).expanduser()
    digest = hashlib.sha256(str(target).encode("utf-8")).hexdigest()
    record = paths["originals"] / app / (digest + ".json")
    backup = paths["originals"] / app / (digest + ".original")
    return target, record, backup


def _snapshot_file(paths, app, target):
    target, record, backup = _file_record(paths, app, target)
    if record.exists():
        return
    record.parent.mkdir(parents=True, exist_ok=True)
    existed = target.is_file()
    if existed:
        shutil.copy2(target, backup)
    _atomic_json(record, {"target": str(target), "existed": existed, "backup": str(backup)})


def _restore_file(paths, app, target):
    target, record, backup = _file_record(paths, app, target)
    if not record.exists():
        return
    try:
        data = json.loads(record.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    if data.get("existed") and backup.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(backup, target)
    else:
        try:
            target.unlink()
        except FileNotFoundError:
            pass


def _tree_record(paths, app, target):
    target = Path(target).expanduser()
    digest = hashlib.sha256(str(target).encode("utf-8")).hexdigest()
    record = paths["originals"] / app / (digest + ".json")
    backup = paths["originals"] / app / (digest + ".original-tree")
    return target, record, backup


def _snapshot_tree(paths, app, target):
    target, record, backup = _tree_record(paths, app, target)
    if record.exists():
        return
    record.parent.mkdir(parents=True, exist_ok=True)
    existed = target.is_dir()
    backup_source = None
    # Reuse the timestamped backup the user already made before this manager
    # was installed, when one exists; otherwise make our own baseline copy.
    if existed:
        pattern_root = paths["home"] / ".local/state/veyra-app-themes/backups"
        if pattern_root.is_dir():
            candidates = sorted(pattern_root.glob("*/icons") , reverse=True)
            for icons_dir in candidates:
                candidate = icons_dir / target.name
                if candidate.is_dir():
                    backup_source = candidate
                    break
        if backup_source is None:
            shutil.copytree(target, backup, symlinks=True)
            backup_source = backup
    _atomic_json(record, {"target": str(target), "existed": existed, "backup": str(backup_source) if backup_source else ""})


def _restore_tree(paths, app, target):
    target, record, _unused = _tree_record(paths, app, target)
    if not record.exists():
        return
    try:
        data = json.loads(record.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    if target.is_symlink() or not target.is_dir():
        # Files and symlinks (including symlinks to directories) must be
        # unlinked; rmtree would follow/fail on them and abort the restore.
        try:
            target.unlink()
        except FileNotFoundError:
            pass
    else:
        shutil.rmtree(target)
    if data.get("existed"):
        backup = Path(data.get("backup", ""))
        if backup.is_dir():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(backup, target, symlinks=True)


def _get_icon_theme(paths):
    record = paths["originals"] / "papirus-icons" / "original-icon-theme.json"
    if record.exists():
        return
    record.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"], capture_output=True, text=True, timeout=4)
        if result.returncode == 0:
            value = result.stdout.strip()
            if len(value) >= 2 and value[0] == "'" and value[-1] == "'":
                value = value[1:-1]
            _atomic_json(record, {"value": value})
    except (OSError, subprocess.SubprocessError):
        pass


def _restore_icon_theme(paths):
    record = paths["originals"] / "papirus-icons" / "original-icon-theme.json"
    if not record.exists():
        return
    try:
        value = json.loads(record.read_text(encoding="utf-8")).get("value")
        if value:
            subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", value], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass


def _semantic_palette(home, colors, dark):
    palette = dict(colors)
    try:
        from matugen_palette import generate
        accent = colors.get("accent", "#a77ef5")
        palette.update(generate(accent, dark))
    except Exception as exc:
        print(f"Veyra app themes: couldn't generate {'dark' if dark else 'light'} Matugen palette: {exc}")
    return palette


def _value_for_role(palette, role):
    value = palette.get("m3_" + role)
    if not value:
        for alias in ALIASES.get(role, ()):
            value = palette.get(alias)
            if value:
                break
    if not isinstance(value, str) or not value:
        return None
    if not value.startswith("#") and re.fullmatch(r"[0-9a-fA-F]{6,8}", value):
        value = "#" + value
    if not re.fullmatch(r"#[0-9a-fA-F]{6,8}", value):
        return None
    return value


def _render_text(text, colors, dark_palette, light_palette):
    # Default placeholders use the Material palette matching the wallpaper.
    default_palette = dict(colors)
    use_dark = bool(colors.get("wallpaperIsDark", True))
    default_palette.update(dark_palette if use_dark else light_palette)

    def replace(match):
        role, mode, fmt = match.groups()
        palette = (
            default_palette if mode == "default"
            else dark_palette if mode == "dark"
            else light_palette
        )
        value = _value_for_role(palette, role)
        if value is None:
            # Keep compatibility with older palettes and custom aliases.
            value = _value_for_role(colors, role)
        if value is None:
            return match.group(0)
        return value.lstrip("#") if fmt == "hex_stripped" else value

    return PLACEHOLDER.sub(replace, text)



def _render_file(source, target, colors, dark_palette, light_palette, preserve_inode=False):
    source = Path(source)
    if not source.is_file():
        raise FileNotFoundError(f"Template missing: {source}")
    rendered = _render_text(source.read_text(encoding="utf-8"), colors, dark_palette, light_palette)
    leftovers = PLACEHOLDER.findall(rendered)
    if leftovers:
        raise ValueError(f"Unresolved color placeholders in {source}: {leftovers[:5]}")
    if preserve_inode:
        _write_text_in_place(target, rendered)
    else:
        _write_text(target, rendered)


def _remove_lines_matching(path, predicate):
    path = Path(path)
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines(keepends=True)
    kept = [line for line in lines if not predicate(line)]
    updated = "".join(kept)
    if updated != text:
        _write_text(path, updated)


def _update_import(css_file, import_path, enable):
    css_file = Path(css_file)
    css_file.parent.mkdir(parents=True, exist_ok=True)
    exists = css_file.is_file()
    text = css_file.read_text(encoding="utf-8", errors="replace") if exists else ""
    # Drop a previous Veyra line and the exact old Noctalia template import.
    lines = text.splitlines()
    lines = [line for line in lines if import_path not in line and (not enable or "/noctalia/zen-browser/zen-user" not in line)]
    if enable:
        new_line = f'@import "{import_path}";'
        lines.insert(0, new_line)
    updated = "\n".join(lines)
    if text.endswith("\n") and updated:
        updated += "\n"
    if updated != text:
        _write_text(css_file, updated)


def _update_user_js(user_js, enable):
    user_js = Path(user_js)
    user_js.parent.mkdir(parents=True, exist_ok=True)
    text = user_js.read_text(encoding="utf-8", errors="replace") if user_js.is_file() else ""
    lines = text.splitlines()
    output = []
    inside = False
    for line in lines:
        if line.strip() == USERJS_BEGIN:
            inside = True
            continue
        if line.strip() == USERJS_END:
            inside = False
            continue
        if not inside:
            output.append(line)
    if enable:
        if output and output[-1].strip():
            output.append("")
        output.extend([
            USERJS_BEGIN,
            'user_pref("devtools.chrome.enabled", true);',
            'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);',
            USERJS_END,
        ])
    updated = "\n".join(output).rstrip() + ("\n" if output else "")
    if updated != text:
        _write_text(user_js, updated)


def _zen_profiles(home):
    found = set()
    for base in (config_home(home) / "zen", Path(home) / ".zen"):
        if not base.is_dir():
            continue
        for root, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in {"cache", "storage", "crashes"}]
            if "prefs.js" in files:
                found.add(Path(root))
    return sorted(found)


def _apply_zen(paths, colors, dark_palette, light_palette, enabled):
    app = "zen-browser"
    templates = paths["templates"] / app
    output = paths["cache"] / app
    chrome_out = output / "zen-userChrome.css"
    content_out = output / "zen-userContent.css"
    profiles = _zen_profiles(paths["home"])
    if enabled:
        _render_file(templates / "zen-userChrome.css", chrome_out, colors, dark_palette, light_palette)
        _render_file(templates / "zen-userContent.css", content_out, colors, dark_palette, light_palette)
        for profile in profiles:
            _update_import(profile / "chrome/userChrome.css", str(chrome_out), True)
            _update_import(profile / "chrome/userContent.css", str(content_out), True)
            _update_user_js(profile / "user.js", True)
        _set_active(paths, app, True)
    elif _is_active(paths, app):
        for profile in profiles:
            _update_import(profile / "chrome/userChrome.css", str(chrome_out), False)
            _update_import(profile / "chrome/userContent.css", str(content_out), False)
            _update_user_js(profile / "user.js", False)
        for target in (chrome_out, content_out):
            try:
                target.unlink()
            except FileNotFoundError:
                pass
        _set_active(paths, app, False)


def _spicetify_targets(home):
    config = config_home(home) / "spicetify/Themes"
    return {
        "Comfy": (config / "Comfy/color.ini", "spicetify.ini"),
        "Colorful": (config / "Colorful/color.ini", "spicetify_colorful.ini"),
        "marketplace": (config / "marketplace/color.ini", "spicetify_marketplace.ini"),
    }


def _spicetify_bin(home):
    found = shutil.which("spicetify")
    if found:
        return found
    local_bin = Path(home).expanduser() / ".spicetify/spicetify"
    return str(local_bin) if local_bin.is_file() else None


def _run_spicetify(home=None):
    spicetify = _spicetify_bin(home or Path.home())
    if not spicetify:
        print("Veyra app themes: Spicetify command not found; generated color.ini files are ready but weren't applied.")
        return
    try:
        result = subprocess.run([spicetify, "-q", "apply", "--no-restart"], check=False, timeout=60, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            print("Veyra app themes: Spicetify apply returned non-zero; check `spicetify` output if Spotify did not update.")
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"Veyra app themes: could not run Spicetify apply: {exc}")


def _refresh_spicetify(home=None):
    spicetify = _spicetify_bin(home or Path.home())
    if not spicetify:
        print("Veyra: Spicetify not found; skipped Spotify refresh.")
        return False
    try:
        result = subprocess.run(
            [spicetify, "-q", "refresh", "--no-restart"],
            check=False, timeout=60,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, text=True,
        )
        if result.returncode != 0:
            print(
                "Veyra: Spicetify refresh failed: "
                + (result.stderr.strip() or f"exit code {result.returncode}")
            )
            return False
        return True
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"Veyra: Spotify theme refresh failed: {exc}")
        return False


def _reload_spotify_ui():
    if not shutil.which("hyprctl"):
        print("Veyra: hyprctl not found; skipped Spotify GUI reload.")
        return

    import json

    try:
        clients = subprocess.run(
            ["hyprctl", "-j", "clients"],
            check=False, timeout=5,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True,
        )
        active = subprocess.run(
            ["hyprctl", "-j", "activeworkspace"],
            check=False, timeout=5,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True,
        )

        if clients.returncode != 0 or active.returncode != 0:
            print("Veyra: couldn't inspect Hyprland windows; skipped Spotify GUI reload.")
            return

        try:
            client_list = json.loads(clients.stdout)
            active_workspace = json.loads(active.stdout)
        except (ValueError, TypeError):
            print("Veyra: couldn't parse Hyprland window data; skipped Spotify GUI reload.")
            return

        active_id = str(active_workspace.get("id", ""))
        visible_spotify = any(
            str(client.get("class", "")).lower() == "spotify"
            and client.get("mapped", True)
            and not client.get("hidden", False)
            and str((client.get("workspace") or {}).get("id", "")) == active_id
            for client in client_list
        )

        if not visible_spotify:
            print("Veyra: Spotify isn't visible on the active workspace; skipped GUI reload.")
            return

        result = subprocess.run(
            [
                "hyprctl", "dispatch",
                "hl.dsp.send_shortcut({ mods = 'CTRL + SHIFT', "
                "key = 'R', window = 'class:Spotify' })",
            ],
            check=False, timeout=5,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True,
        )
        if result.returncode != 0:
            print(
                "Veyra: Spotify GUI reload failed: "
                + (result.stderr.strip() or result.stdout.strip())
            )
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"Veyra: could not reload Spotify GUI: {exc}")

def _apply_spicetify(paths, colors, dark_palette, light_palette, enabled):
    app = "spicetify"
    was_active = _is_active(paths, app)
    target_defs = _spicetify_targets(paths["home"])
    existing = {
        name: (target, template)
        for name, (target, template) in target_defs.items()
        if target.parent.is_dir()
    }

    if enabled:
        files_changed = False
        for name, (target, template_name) in existing.items():
            # Compare the actual generated file, not just whether its writer ran.
            try:
                previous_content = target.read_bytes() if target.is_file() else None
            except OSError:
                previous_content = object()

            _snapshot_file(paths, app, target)
            source = paths["templates"] / app / template_name
            _render_file(source, target, colors, dark_palette, light_palette,
                         preserve_inode=True)

            try:
                current_content = target.read_bytes() if target.is_file() else None
            except OSError:
                current_content = object()
            if current_content != previous_content:
                files_changed = True

        _set_active(paths, app, True)

        if was_active:
            # Refresh only when Veyra actually changed a generated color file.
            if files_changed:
                if not _refresh_spicetify(paths["home"]):
                    return
            else:
                print("Veyra app themes: Spicetify files unchanged; skipped refresh.")
        else:
            # First activation still needs Spicetify to apply its customizations.
            _run_spicetify(paths["home"])

        # Reload Spotify only when the theme changed or was first activated.
        if files_changed or not was_active:
            _reload_spotify_ui()

    elif _is_active(paths, app):
        for target, _template_name in target_defs.values():
            _restore_file(paths, app, target)
        _set_active(paths, app, False)
        _run_spicetify(paths["home"])
        _reload_spotify_ui()
def _heroic_targets(home):
    targets = []
    native = config_home(home) / "heroic"
    flatpak = Path(home) / ".var/app/com.heroicgameslauncher.hgl/config/heroic"
    if native.is_dir():
        targets.append(native / "themes/matugen.css")
    if flatpak.parent.parent.is_dir():
        targets.append(flatpak / "themes/matugen.css")
    return targets


def _apply_heroic(paths, colors, dark_palette, light_palette, enabled):
    app = "heroiclauncher"
    targets = _heroic_targets(paths["home"])
    if enabled:
        source = paths["templates"] / app / "heroic.css"
        for target in targets:
            _snapshot_file(paths, app, target)
            _render_file(source, target, colors, dark_palette, light_palette)
        _set_active(paths, app, True)
    elif _is_active(paths, app):
        for target in targets:
            _restore_file(paths, app, target)
        _set_active(paths, app, False)


def _apply_papirus(paths, colors, dark_palette, light_palette, enabled):
    app = "papirus-icons"
    home = paths["home"]
    variants = ["Papirus", "Papirus-Dark", "Papirus-Light"]
    local_icons = data_home(home) / "icons"
    runtime = paths["cache"] / app
    source_dir = paths["templates"] / app
    active = _is_active(paths, app)
    if not enabled:
        # Wait for a background recolor before restoring original icons.
        if runtime.is_dir() and shutil.which("flock"):
            try:
                subprocess.run(["flock", str(runtime / "apply-papirus.lock"), "true"], check=False, timeout=95, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except (OSError, subprocess.SubprocessError):
                pass
        (runtime / "last-applied-color").unlink(missing_ok=True)
        if active:
            for variant in variants:
                _restore_tree(paths, app, local_icons / variant)
            _restore_icon_theme(paths)
            _set_active(paths, app, False)
        return

    for variant in variants:
        system_variant = Path("/usr/share/icons") / variant
        if system_variant.is_dir():
            _snapshot_tree(paths, app, local_icons / variant)
    _get_icon_theme(paths)
    runtime.mkdir(parents=True, exist_ok=True)
    _render_file(source_dir / "colors", runtime / "colors-final", colors, dark_palette, light_palette)
    papirus_helper = runtime / "papirus-folders"
    papirus_helper_tmp = runtime / f"papirus-folders.{os.getpid()}.tmp"
    shutil.copy2(source_dir / "papirus-folders", papirus_helper_tmp)
    os.chmod(papirus_helper_tmp, 0o755)
    os.replace(papirus_helper_tmp, papirus_helper)
    if not shutil.which("bash"):
        print("Veyra app themes: bash unavailable; cannot run papirus-folders helper.")
        return
    try:
        # Reuse the exact papirus-folders helper shipped with the template;
        # this wrapper selects the closest supported folder color.
        helper_script = runtime / "apply-papirus.sh"
        helper_tmp = helper_script.with_name(f"{helper_script.name}.{os.getpid()}.tmp")
        helper_tmp.write_text(_PAPIRUS_APPLY_WRAPPER, encoding="utf-8")
        os.chmod(helper_tmp, 0o755)
        os.replace(helper_tmp, helper_script)
        log_path = runtime / "apply-papirus.log"
        try:
            with log_path.open("ab") as log_file:
                subprocess.Popen(
                    ["timeout", "90s", "bash", str(helper_script)],
                    stdin=subprocess.DEVNULL, stdout=log_file, stderr=subprocess.STDOUT,
                    start_new_session=True, close_fds=True,
                )
            _set_active(paths, app, True)
            print("Veyra app themes: Papirus recolor queued in background (unchanged folder colors are skipped).")
        except (OSError, subprocess.SubprocessError) as exc:
            print(f"Veyra app themes: could not queue Papirus recolor: {exc}")
    except (OSError, subprocess.SubprocessError, IndexError) as exc:
        print(f"Veyra app themes: Papirus recolor failed: {exc}")


_PAPIRUS_APPLY_WRAPPER = r"""#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
COLOR_FILE="$HERE/colors-final"
[[ -f "$COLOR_FILE" ]] || exit 1
# Serialize detached workers; read the palette only after acquiring the lock.
exec 9>"$HERE/apply-papirus.lock"
flock 9
mapfile -t lines < "$COLOR_FILE"
TARGET="${lines[0]//[# ]/}"
[[ ${#TARGET} -ge 6 ]] || exit 1
TARGET=${TARGET:0:6}
TR=$((16#${TARGET:0:2})); TG=$((16#${TARGET:2:2})); TB=$((16#${TARGET:4:2}))
MAPPING="${lines[${#lines[@]}-1]}"
closest=$(awk -v r="$TR" -v g="$TG" -v b="$TB" -v m="$MAPPING" '
function rgb2hsv(r,g,b, mx,mn,d,h,s,v,t) {
  r/=255; g/=255; b/=255
  mx = (r>g)?(r>b?r:b):(g>b?g:b); mn = (r<g)?(r<b?r:b):(g<b?g:b); v = mx; d = mx-mn
  if (d == 0) { s=0; h=0 } else { s=d/mx; if (mx==r) { t=(g-b)/d; if(t<0)t+=6; h=60*t } else if(mx==g) h=60*(((b-r)/d)+2); else h=60*(((r-g)/d)+4) }
  return h SUBSEP s SUBSEP v
}
BEGIN {
  WH=10; WS=1; WV=0.3; split(rgb2hsv(r,g,b), tgt, SUBSEP); th=tgt[1]; ts=tgt[2]; tv=tgt[3]; n=split(m, arr)
  for(i=1;i<=n;i++){ split(arr[i],p,":"); cr=strtonum("0x" substr(p[2],1,2)); cg=strtonum("0x" substr(p[2],3,2)); cb=strtonum("0x" substr(p[2],5,2)); split(rgb2hsv(cr,cg,cb),c,SUBSEP); ch=c[1]; cs=c[2]; cv=c[3]; dh=th-ch; if(dh<0)dh=-dh; if(dh>180)dh=360-dh; dh/=180; ds=ts-cs; dv=tv-cv; d=WH*(ts*cs)*dh*dh+WS*ds*ds+WV*dv*dv; if(min==""||d<min){min=d;name=p[1]}}
  print name
}')
SURFACE="${lines[1]//[# ]/}"
ICON_VARIANT="Papirus-Dark"
if [[ ${#SURFACE} -ge 6 ]]; then
  SURFACE=${SURFACE:0:6}; SR=$((16#${SURFACE:0:2})); SG=$((16#${SURFACE:2:2})); SB=$((16#${SURFACE:4:2})); LUMA=$(((SR*299+SG*587+SB*114)/1000)); ((LUMA>=128)) && ICON_VARIANT="Papirus-Light"
fi
if command -v gsettings >/dev/null 2>&1; then gsettings set org.gnome.desktop.interface icon-theme "$ICON_VARIANT" 2>/dev/null || true; fi
[[ -n "$closest" ]] || exit 1
if [[ -f "$HERE/last-applied-color" ]] && [[ "$(cat "$HERE/last-applied-color")" == "$closest" ]]; then
  exit 0
fi
APPLY_FAILED=0
for variant in Papirus Papirus-Dark Papirus-Light; do
  [[ -d "/usr/share/icons/$variant" ]] || continue
  ICON_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
  if [[ ! -d "$ICON_HOME/$variant" ]]; then mkdir -p "$ICON_HOME"; cp -r "/usr/share/icons/$variant" "$ICON_HOME/"; fi
  "$HERE/papirus-folders" -t "$variant" -C "$closest" || { echo "papirus-folders failed for $variant" >&2; APPLY_FAILED=1; }
  done
  if [[ "$APPLY_FAILED" -eq 0 ]]; then
    printf '%s\n' "$closest" > "$HERE/last-applied-color"
  else
    exit 1
  fi
"""


def _apply_telegram(paths, colors, dark_palette, light_palette, enabled):
    app = "telegram"
    target = config_home(paths["home"]) / "telegram-desktop/themes/veyra.tdesktop-theme"
    if enabled:
        _snapshot_file(paths, app, target)
        _render_file(paths["templates"] / app / "telegram.tdesktop-theme", target, colors, dark_palette, light_palette)
        _set_active(paths, app, True)
    elif _is_active(paths, app):
        _restore_file(paths, app, target)
        _set_active(paths, app, False)



def _vscodium_targets(home):
    """Find installed NoctaliaTheme files in VSCodium/Code-compatible directories."""
    roots = (
        Path(home) / ".vscode-oss/extensions",
        Path(home) / ".vscode/extensions",
        config_home(home) / "VSCodium/extensions",
        data_home(home) / "vscodium/extensions",
    )
    found = []
    for root in roots:
        if not root.is_dir():
            continue
        for package in root.glob("noctalia.noctaliatheme-*/package.json"):
            try:
                manifest = json.loads(package.read_text(encoding="utf-8"))
                if manifest.get("publisher", "").lower() != "noctalia":
                    continue
                for item in manifest.get("contributes", {}).get("themes", []):
                    if item.get("label") != "NoctaliaTheme" or not item.get("path"):
                        continue
                    theme_path = (package.parent / item["path"]).resolve()
                    if theme_path.is_file():
                        found.append(theme_path)
            except (OSError, ValueError, TypeError):
                continue
    return list(dict.fromkeys(found))


def _vscodium_dynamic_colors(original, palette):
    """Retheme workbench UI colors while preserving syntax-token rules."""
    import re

    def pick(*names, fallback):
        for name in names:
            value = palette.get(name)
            if isinstance(value, str) and re.fullmatch(
                r"#?[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?", value.strip()
            ):
                return "#" + value.strip().lstrip("#")[:6]
        return fallback

    def contrast(color):
        raw = color.lstrip("#")
        r, g, b = (int(raw[i:i + 2], 16) for i in (0, 2, 4))
        return "#171923" if (r * 299 + g * 587 + b * 114) / 1000 > 145 else "#ffffff"

    def alpha(color, opacity):
        return color[:7] + opacity

    surface = pick("m3_surface", "opaqueBg", "bg", fallback="#171923")
    variant = pick("m3_surface_variant", "bgSecondary", "bgTertiary", fallback="#252535")
    on_surface = pick("m3_on_surface", "fg", fallback="#eeeeee")
    muted = pick("m3_on_surface_variant", "muted", fallback="#b0aebe")
    primary = pick("m3_primary", "accent", fallback="#a2cddf")
    on_primary = pick("m3_on_primary", fallback=contrast(primary))
    secondary = pick("m3_secondary", "accentComplementary", fallback=primary)
    tertiary = pick("m3_tertiary", fallback=secondary)
    error = pick("m3_error", fallback="#e06c75")
    outline = pick("m3_outline", "border", fallback="#666477")
    hover = pick("bgAccent", "bgTertiary", fallback=variant)
    shadow = pick("shadow", fallback=surface)

    colors = dict(original)

    # Common UI elements receive explicit roles first.
    fixed = {
        "foreground": on_surface,
        "descriptionForeground": muted,
        "disabledForeground": muted,
        "icon.foreground": muted,
        "focusBorder": primary,
        "selection.background": alpha(primary, "55"),
        "textLink.foreground": primary,
        "textLink.activeForeground": primary,

        "activityBar.background": variant,
        "activityBar.foreground": on_surface,
        "activityBar.inactiveForeground": muted,
        "activityBar.activeBorder": primary,
        "activityBar.border": outline,
        "activityBarBadge.background": primary,
        "activityBarBadge.foreground": on_primary,

        "sideBar.background": variant,
        "sideBar.foreground": on_surface,
        "sideBar.border": outline,
        "sideBarTitle.foreground": on_surface,
        "sideBarSectionHeader.background": variant,
        "sideBarSectionHeader.foreground": on_surface,

        "titleBar.activeBackground": variant,
        "titleBar.activeForeground": on_surface,
        "titleBar.inactiveBackground": variant,
        "titleBar.inactiveForeground": muted,

        "tab.activeBackground": surface,
        "tab.activeForeground": on_surface,
        "tab.inactiveBackground": variant,
        "tab.inactiveForeground": muted,
        "tab.unfocusedActiveBackground": surface,
        "tab.unfocusedActiveForeground": on_surface,
        "tab.unfocusedInactiveBackground": variant,
        "tab.unfocusedInactiveForeground": muted,
        "tab.activeBorderTop": primary,
        "tab.border": outline,
        "editorGroupHeader.tabsBackground": variant,
        "editorGroup.border": outline,

        "editor.background": surface,
        "editor.foreground": on_surface,
        "editorGutter.background": surface,
        "editorLineNumber.foreground": muted,
        "editorLineNumber.activeForeground": primary,
        "editorCursor.foreground": primary,
        "editor.selectionBackground": alpha(primary, "55"),
        "editor.inactiveSelectionBackground": alpha(primary, "30"),
        "editor.lineHighlightBackground": alpha(variant, "A0"),
        "editorWidget.background": variant,
        "editorWidget.border": outline,
        "editorSuggestWidget.background": variant,
        "editorSuggestWidget.foreground": on_surface,
        "editorSuggestWidget.selectedBackground": alpha(primary, "55"),
        "editorSuggestWidget.selectedForeground": on_surface,
        "editorHoverWidget.background": variant,
        "editorHoverWidget.foreground": on_surface,
        "editorHoverWidget.border": outline,
        "editorError.foreground": error,
        "editorWarning.foreground": tertiary,
        "editorInfo.foreground": secondary,
        "editorHint.foreground": secondary,

        "terminal.background": surface,
        "terminal.foreground": on_surface,
        "terminalCursor.foreground": primary,
        "terminal.selectionBackground": alpha(primary, "55"),
        "terminal.ansiBlack": surface,
        "terminal.ansiBrightBlack": muted,
        "terminal.ansiRed": error,
        "terminal.ansiBrightRed": error,
        "terminal.ansiGreen": secondary,
        "terminal.ansiBrightGreen": secondary,
        "terminal.ansiYellow": tertiary,
        "terminal.ansiBrightYellow": tertiary,
        "terminal.ansiBlue": primary,
        "terminal.ansiBrightBlue": primary,
        "terminal.ansiMagenta": secondary,
        "terminal.ansiBrightMagenta": secondary,
        "terminal.ansiCyan": secondary,
        "terminal.ansiBrightCyan": secondary,
        "terminal.ansiWhite": on_surface,
        "terminal.ansiBrightWhite": on_surface,

        "panel.background": surface,
        "panel.border": outline,
        "panelTitle.activeBorder": primary,
        "panelTitle.activeForeground": on_surface,
        "panelTitle.inactiveForeground": muted,

        "statusBar.background": variant,
        "statusBar.foreground": on_surface,
        "statusBar.border": outline,
        "statusBarItem.hoverBackground": alpha(primary, "35"),

        "input.background": variant,
        "input.foreground": on_surface,
        "input.border": outline,
        "input.placeholderForeground": muted,
        "dropdown.background": variant,
        "dropdown.foreground": on_surface,
        "quickInput.background": variant,
        "quickInput.foreground": on_surface,

        "list.activeSelectionBackground": alpha(primary, "55"),
        "list.activeSelectionForeground": on_surface,
        "list.hoverBackground": alpha(hover, "60"),

        "button.background": primary,
        "button.foreground": on_primary,
        "button.hoverBackground": hover,
        "badge.background": primary,
        "badge.foreground": on_primary,
        "progressBar.background": primary,

        "notificationCenterHeader.background": variant,
        "notificationCenterHeader.foreground": on_surface,
        "notifications.background": variant,
        "notifications.foreground": on_surface,
        "menu.background": variant,
        "menu.foreground": on_surface,
        "menu.selectionBackground": alpha(primary, "45"),
        "menu.selectionForeground": on_surface,

        "peekView.border": primary,
        "peekViewTitle.background": variant,
        "peekViewTitleLabel.foreground": on_surface,
        "peekViewTitleDescription.foreground": muted,
        "peekViewEditor.background": surface,
        "peekViewResult.background": variant,
        "peekViewResult.selectionBackground": alpha(primary, "45"),

        "diffEditor.insertedTextBackground": alpha(secondary, "30"),
        "diffEditor.removedTextBackground": alpha(error, "30"),
        "editorOverviewRuler.border": outline,
        "scrollbarSlider.background": alpha(outline, "70"),
        "scrollbarSlider.hoverBackground": alpha(outline, "B0"),
        "minimapSlider.background": alpha(outline, "70"),
        "widget.shadow": shadow,
    }

    def infer_color(key):
        low = key.lower()

        if "activeborder" in low or "focusborder" in low:
            return primary
        if "selection" in low and "background" in low:
            return alpha(primary, "55")
        if "hover" in low and "background" in low:
            return alpha(hover, "65")
        if any(word in low for word in ("inserted", "added")) and "background" in low:
            return alpha(secondary, "30")
        if any(word in low for word in ("removed", "deleted")) and "background" in low:
            return alpha(error, "30")

        if "background" in low:
            if any(word in low for word in (
                "button", "badge", "progressbar"
            )):
                return primary
            if any(word in low for word in (
                "editor", "terminal", "panel", "debugconsole",
                "peekvieweditor", "notebook", "interactivewindow"
            )):
                return surface
            return variant

        if "foreground" in low:
            if "error" in low:
                return error
            if "warning" in low:
                return tertiary
            if any(word in low for word in ("inserted", "added", "changed")):
                return secondary
            if any(word in low for word in ("removed", "deleted")):
                return error
            if any(word in low for word in (
                "inactive", "disabled", "placeholder", "description",
                "linenumber", "breadcrumb", "unfocused", "comment"
            )):
                return muted
            if any(word in low for word in ("button", "badge")):
                return on_primary
            if any(word in low for word in (
                "cursor", "link", "highlight", "findmatch", "active"
            )):
                return primary
            return on_surface

        if "border" in low or "separator" in low:
            return primary if "active" in low or "focus" in low else outline
        return None

    # Recolor the existing UI keys and any other recognizable workbench roles.
    # Keep tokenColors and semanticTokenColors exactly as supplied by the extension.
    for key in list(colors):
        value = fixed.get(key)
        if value is None:
            value = infer_color(key)
        if value is not None:
            colors[key] = value

    return colors


def _apply_vscodium(paths, colors, dark_palette, light_palette, enabled):
    app = "vscodium"
    targets = _vscodium_targets(paths["home"])
    active = _is_active(paths, app)

    if not enabled:
        if active:
            for target in targets:
                _restore_file(paths, app, target)
            _set_active(paths, app, False)
        return

    if not targets:
        print("Veyra app themes: No installed NoctaliaTheme file found for VSCodium.")
        return

    template = paths["templates"] / "vscode-community.json"
    if not template.is_file():
        print(f"Veyra app themes: VSCodium template missing: {template}")
        return

    try:
        # Default placeholders follow the current wallpaper's light/dark mode.
        current = dict(colors)
        use_dark = bool(colors.get("wallpaperIsDark", True))
        current.update(dark_palette if use_dark else light_palette)

        # Supply the ANSI terminal roles expected by the community template.
        terminal = {
            "black": "m3_surface_container_lowest",
            "red": "m3_error",
            "green": "m3_tertiary",
            "yellow": "m3_secondary",
            "blue": "m3_primary",
            "magenta": "m3_tertiary",
            "cyan": "m3_secondary",
            "white": "m3_on_surface",
            "bright_black": "m3_outline",
            "bright_red": "m3_error",
            "bright_green": "m3_tertiary_container",
            "bright_yellow": "m3_secondary_container",
            "bright_blue": "m3_primary_container",
            "bright_magenta": "m3_tertiary",
            "bright_cyan": "m3_secondary_container",
            "bright_white": "m3_on_surface",
        }
        for name, role in terminal.items():
            value = current.get(role)
            if not value:
                raise ValueError(f"Missing Material palette role for terminal color: {role}")
            current["m3_terminal_" + name] = value

        for name in ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"):
            current["m3_terminal_normal_" + name] = current["m3_terminal_" + name]

        template_text = template.read_text(encoding="utf-8")
        rendered = _render_text(template_text, current, dark_palette, light_palette)
        leftovers = PLACEHOLDER.findall(rendered)
        if leftovers:
            roles = sorted({role for role, _mode, _fmt in leftovers})
            raise ValueError(f"Unresolved template color roles: {roles}")

        document = json.loads(rendered)
        if not isinstance(document.get("colors"), dict):
            raise ValueError("Community template has no valid workbench colors.")
        if not isinstance(document.get("tokenColors"), list):
            raise ValueError("Community template has no valid syntax token rules.")

    except (OSError, ValueError, TypeError) as exc:
        print(f"Veyra app themes: VSCodium template validation failed: {exc}")
        return

    applied = False
    for target in targets:
        try:
            _snapshot_file(paths, app, target)
            _write_text(target, rendered)
            applied = True
        except (OSError, ValueError, TypeError) as exc:
            print(f"Veyra app themes: VSCodium update failed for {target}: {exc}")

    if applied:
        _set_active(paths, app, True)
        print("Veyra app themes: VSCodium community template applied.")


def apply(home, colors):
    """Called by apply_theme.py whenever Veyra regenerates its palette."""
    paths = _paths(home)
    for directory in (paths["state"], paths["originals"], paths["active"], paths["cache"]):
        directory.mkdir(parents=True, exist_ok=True)
    prefs = _load_preferences(paths["prefs"])
    enabled = {app: bool(prefs.get(setting, False)) for app, setting in SETTING_KEYS.items()}

    # Zen contains explicit .dark and .light placeholders; compute both modes
    # only when it is enabled. Other templates use .default and current colors.
    if enabled["zen-browser"]:
        dark_palette = _semantic_palette(home, colors, True)
        light_palette = _semantic_palette(home, colors, False)
    else:
        dark_palette = dict(colors)
        light_palette = dict(colors)

    handlers = (
        ("zen-browser", _apply_zen),
        ("spicetify", _apply_spicetify),
        ("heroiclauncher", _apply_heroic),
        ("papirus-icons", _apply_papirus),
        ("telegram", _apply_telegram),
        ("vscodium", _apply_vscodium),
    )
    for app, handler in handlers:
        try:
            handler(paths, colors, dark_palette, light_palette, enabled[app])
        except Exception as exc:
            print(f"Veyra app theme '{app}' failed: {exc}")
