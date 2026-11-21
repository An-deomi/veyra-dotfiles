#!/usr/bin/env python3
"""Ask running toolkit applications to reload freshly generated Veyra colors.

This is best-effort: applications that ignore desktop/theme change notifications
cannot be forced to rebuild their style without application-specific support.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path

from xdg_paths import config_home


def run(args: list[str], timeout: float = 4.0) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.SubprocessError):
        return None


def gsettings_get(key: str) -> str | None:
    result = run(["gsettings", "get", "org.gnome.desktop.interface", key])
    if result is None or result.returncode != 0:
        return None
    value = result.stdout.strip()
    if len(value) >= 2 and value[0] == "'" and value[-1] == "'":
        return value[1:-1]
    return value or None


def gsettings_set(key: str, value: str) -> bool:
    result = run(["gsettings", "set", "org.gnome.desktop.interface", key, value])
    return result is not None and result.returncode == 0


def refresh_gtk(dry_run: bool = False) -> list[str]:
    actions: list[str] = []
    theme = gsettings_get("gtk-theme")
    if theme:
        # GTK3 reloads its theme provider on an actual theme-name change. Prefer
        # the sibling adw-gtk3 variant when that's the configured Veyra base;
        # otherwise use a known fallback and restore the exact selected theme.
        if theme == "adw-gtk3-dark":
            temporary = "adw-gtk3"
        elif theme == "adw-gtk3":
            temporary = "adw-gtk3-dark"
        elif theme != "Adwaita":
            temporary = "Adwaita"
        else:
            temporary = "HighContrast"
        if dry_run:
            actions.append(f"GTK3: switch theme {theme!r} -> {temporary!r} -> {theme!r}")
        elif gsettings_set("gtk-theme", temporary) and gsettings_set("gtk-theme", theme):
            actions.append("GTK3: requested a theme-change notification (custom gtk.css reload is not guaranteed)")
        else:
            # Try restoring the original setting even if the first set failed.
            gsettings_set("gtk-theme", theme)
            actions.append("GTK3: theme refresh could not be requested (setting is unavailable)")

    # VEYRA_V16_NO_DUPLICATE_GTK4_TOGGLE: theme_appliers/gtk.py already
    # toggles the system color-scheme after writing the GTK palette. Avoid
    # sending a second opposite->desired pair here.

    # Under XWayland, nudge xsettingsd if present so GTK3 clients receive changes.
    xsettings = run(["pgrep", "-x", "xsettingsd"])
    if xsettings is not None and xsettings.returncode == 0:
        if dry_run:
            actions.append("XSettings: send SIGHUP to xsettingsd")
        else:
            result = run(["pkill", "-HUP", "-x", "xsettingsd"])
            actions.append("XSettings: signalled xsettingsd" if result is not None and result.returncode == 0 else "XSettings: couldn't signal xsettingsd")
    return actions


def refresh_qt(home: Path, dry_run: bool = False) -> list[str]:
    actions: list[str] = []
    for relative in ("qt5ct/qt5ct.conf", "qt6ct/qt6ct.conf"):
        config = config_home(home) / relative
        if not config.is_file():
            continue
        if dry_run:
            actions.append(f"Qt: touch {config}")
            continue
        try:
            # qt5ct/qt6ct watch their own configuration and can send a ThemeChange
            # to running applications. Touch; don't replace or rewrite user files.
            os.utime(config, None)
            actions.append(f"Qt: requested live refresh through {config.name}")
        except OSError as exc:
            actions.append(f"Qt: couldn't refresh {config.name}: {exc}")
    if not actions:
        actions.append("Qt: no qt5ct/qt6ct config file found; only KDE notification may apply")
    return actions


def notify_kde(home: Path, dry_run: bool = False) -> list[str]:
    actions: list[str] = []
    kdeglobals = config_home(home) / "kdeglobals"
    if kdeglobals.is_file():
        if dry_run:
            actions.append(f"KDE: touch {kdeglobals}")
        else:
            try:
                os.utime(kdeglobals, None)
                actions.append("KDE: refreshed kdeglobals modification time")
            except OSError as exc:
                actions.append(f"KDE: couldn't touch kdeglobals: {exc}")

    dbus_send = shutil.which("dbus-send")
    if not dbus_send:
        actions.append("KDE: dbus-send not installed; skipped palette notification")
        return actions
    # KGlobalSettings::ChangeType enum: PaletteChanged=0, FontChanged=1,
    # StyleChanged=2. Use 0 here; 2 only requests a widget-style refresh.
    signal = [dbus_send, "--session", "--type=signal", "/KGlobalSettings",
              "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"]
    if dry_run:
        actions.append("KDE: emit KGlobalSettings PaletteChanged notification")
    else:
        result = run(signal)
        if result is not None and result.returncode == 0:
            actions.append("KDE: emitted PaletteChanged notification for running KDE apps")
        else:
            detail = ((result.stderr or result.stdout).strip() if result else "dbus-send failed")
            actions.append(f"KDE: palette notification unavailable: {detail[:180]}")
    return actions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gtk", action="store_true", help="refresh running GTK applications")
    parser.add_argument("--qt", action="store_true", help="refresh running qt5ct/qt6ct applications")
    parser.add_argument("--kde", action="store_true", help="notify running KDE applications")
    parser.add_argument("--dry-run", action="store_true", help="print actions without changing settings")
    args = parser.parse_args()
    home = Path.home()
    actions: list[str] = []
    if args.gtk:
        actions.extend(refresh_gtk(args.dry_run))
    if args.qt:
        actions.extend(refresh_qt(home, args.dry_run))
    if args.kde:
        actions.extend(notify_kde(home, args.dry_run))
    for action in actions:
        print("Veyra live theme:", action)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
