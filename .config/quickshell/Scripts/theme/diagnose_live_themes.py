#!/usr/bin/env python3
"""Read-only diagnostics for Veyra's Qt/KDE and GTK theme integration.

Only prints a small allowlist of theme-related environment variables; it never
prints the full process environment or modifies any settings/files.
"""
from __future__ import annotations

import configparser
import os
from pathlib import Path
import subprocess

from xdg_paths import config_home

HOME = Path.home()
ENV_KEYS = (
    "QT_QPA_PLATFORMTHEME",
    "QT_QPA_PLATFORMTHEME_QT6",
    "QT_STYLE_OVERRIDE",
    "QT_QUICK_CONTROLS_STYLE",
    "QT_PLUGIN_PATH",
    "GTK_THEME",
)
APP_NAMES = {
    "dolphin", "kate", "okular", "gwenview", "kcalc", "ark", "spectacle",
    "systemsettings", "konsole", "kwrite", "kdenlive", "keepassxc", "vlc",
    "qutebrowser", "gimp", "nautilus", "thunar", "pavucontrol",
    "nm-connection-editor", "firefox", "zen", "chromium", "chromium-browser",
}


def read_ini(path: Path, section: str, keys: tuple[str, ...]) -> dict[str, str]:
    parser = configparser.ConfigParser()
    parser.optionxform = str.lower
    try:
        parser.read(path, encoding="utf-8")
        return {key: parser.get(section, key, fallback="<unset>") for key in keys}
    except (OSError, configparser.Error):
        return {key: "<unreadable>" for key in keys}


def gsettings(key: str) -> str:
    try:
        result = subprocess.run(
            ["gsettings", "get", "org.gnome.desktop.interface", key],
            capture_output=True, text=True, timeout=3, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return "<gsettings unavailable>"
    if result.returncode != 0:
        return "<unavailable>"
    return result.stdout.strip()


def process_details() -> list[tuple[int, str, dict[str, str]]]:
    output = []
    proc_root = Path("/proc")
    try:
        proc_entries = list(proc_root.iterdir())
    except OSError:
        return output
    for entry in proc_entries:
        if not entry.name.isdigit():
            continue
        try:
            raw_cmd = (entry / "cmdline").read_bytes().split(b"\0")
            args = [arg.decode("utf-8", "replace") for arg in raw_cmd if arg]
            if not args:
                continue
            name = Path(args[0]).name
            if name not in APP_NAMES:
                try:
                    name = (entry / "comm").read_text(encoding="utf-8").strip()
                except OSError:
                    continue
            if name not in APP_NAMES:
                # Some launchers put their executable after a wrapper argument.
                match = next((Path(arg).name for arg in args if Path(arg).name in APP_NAMES), None)
                if not match:
                    continue
                name = match
            raw_env = (entry / "environ").read_bytes().split(b"\0")
            env = {}
            for item in raw_env:
                if b"=" not in item:
                    continue
                key_b, value_b = item.split(b"=", 1)
                key = key_b.decode("ascii", "ignore")
                if key in ENV_KEYS:
                    env[key] = value_b.decode("utf-8", "replace")
            output.append((int(entry.name), name, env))
        except (OSError, PermissionError, ProcessLookupError):
            continue
    return sorted(output, key=lambda item: (item[1], item[0]))


def main() -> int:
    print("=== Veyra live-theme diagnostics (read-only) ===")
    print("Session environment:")
    for key in ENV_KEYS:
        print(f"  {key}={os.environ.get(key, '<unset>')}")

    print("\nQt configuration:")
    for toolkit in ("qt5ct", "qt6ct"):
        conf = config_home(HOME) / toolkit / f"{toolkit}.conf"
        values = read_ini(conf, "Appearance", ("color_scheme_path", "custom_palette", "style"))
        scheme = values.get("color_scheme_path", "<unset>")
        scheme_exists = Path(scheme).is_file() if scheme not in ("<unset>", "<unreadable>") else False
        print(f"  {conf}: {'exists' if conf.is_file() else 'MISSING'}")
        for key, value in values.items():
            print(f"    {key}={value}")
        if scheme not in ("<unset>", "<unreadable>"):
            print(f"    scheme_file_exists={scheme_exists}")

    plugin_roots = [Path("/usr/lib/qt5/plugins/platformthemes"), Path("/usr/lib/qt6/plugins/platformthemes")]
    plugin_files = []
    for root in plugin_roots:
        if root.is_dir():
            try:
                plugin_files.extend(str(path) for path in root.glob("*qt*ct*.so"))
                plugin_files.extend(str(path) for path in root.glob("*kde*.so"))
            except OSError:
                pass
    print("  detected platform-theme plugin files:")
    if plugin_files:
        for path in sorted(set(plugin_files)):
            print(f"    {path}")
    else:
        print("    <none at standard /usr/lib/qt*/plugins/platformthemes paths>")

    print("\nRunning app theme environment (only selected variables):")
    apps = process_details()
    if not apps:
        print("  <no known target apps visible, or /proc access unavailable>")
    for pid, name, env in apps:
        print(f"  {name} (pid {pid}):")
        for key in ENV_KEYS:
            if key in env:
                print(f"    {key}={env[key] or '<empty>'}")
        if not any(key in env for key in ENV_KEYS):
            print("    theme variables are unset in this process")

    print("\nGTK/KDE settings:")
    for key in ("gtk-theme", "color-scheme"):
        print(f"  gsettings {key}={gsettings(key)}")
    kdeglobals = config_home(HOME) / "kdeglobals"
    kde = read_ini(kdeglobals, "General", ("colorscheme",))
    print(f"  kdeglobals General/ColorScheme={kde.get('colorscheme', '<unset>')}")
    for ver in ("gtk-3.0", "gtk-4.0"):
        folder = config_home(HOME) / ver
        css = folder / "veyra.css"
        main_css = folder / "gtk.css"
        imported = False
        try:
            imported = 'url("veyra.css")' in main_css.read_text(encoding="utf-8")
        except OSError:
            pass
        has_rules = False
        try:
            text = css.read_text(encoding="utf-8")
            has_rules = "window, .background {" in text and "button:hover" in text
        except OSError:
            pass
        print(f"  {ver}: gtk.css={'exists' if main_css.is_file() else 'MISSING'}, imports_veyra={imported}, veyra.css={'exists' if css.is_file() else 'MISSING'}, widget_rules={has_rules}")

    print("\nInterpretation:")
    print("  Qt/KDE live updates require each running app to have loaded a compatible platform-theme/style plugin; changing environment variables now only affects newly launched apps.")
    print("  GTK custom CSS is loaded by apps as they initialize; GTK4/libadwaita does not guarantee live reload of a rewritten user CSS file.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
