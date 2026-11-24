#!/usr/bin/env python3
import sys
sys.dont_write_bytecode = True

import shutil
import subprocess
from pathlib import Path

from xdg_paths import is_live_session

def main():
    if len(sys.argv) < 3:
        print("Usage: apply_cursor.py <ThemeName> <Size>", file=sys.stderr)
        sys.exit(1)

    theme_name = sys.argv[1]
    try:
        size = int(sys.argv[2])
        if not 1 <= size <= 256:
            raise ValueError()
    except ValueError:
        print("Cursor size must be between 1 and 256", file=sys.stderr)
        sys.exit(1)

    if not theme_name or any(c in theme_name for c in '"\\\n\r'):
        print("Invalid cursor theme name", file=sys.stderr)
        sys.exit(1)

    home = Path.home()
    live = is_live_session(home)

    if live and shutil.which("gsettings"):
        subprocess.run(
            ["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme_name],
            capture_output=True,
            check=False,
        )
        subprocess.run(
            ["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)],
            capture_output=True,
            check=False,
        )

    icons_dir = home / ".icons" / "default"
    icons_dir.mkdir(parents=True, exist_ok=True)
    (icons_dir / "index.theme").write_text(
        f"[Icon Theme]\nInherits={theme_name}\n", encoding="utf-8"
    )

    writer = (
        Path(__file__).resolve().parents[2]
        / "Core" / "Services" / "scripts" / "update_veyra_prefs.py"
    )
    subprocess.run(
        [sys.executable, str(writer), __import__("json").dumps({
            "cursor_theme": theme_name,
            "cursor_size": size,
        })],
        check=True,
    )

    if live and shutil.which("hyprctl"):
        result = subprocess.run(
            ["hyprctl", "setcursor", theme_name, str(size)],
            capture_output=True, text=True, check=False,
        )
        if result.returncode:
            print(f"Warning: hyprctl setcursor failed: {result.stderr.strip()}", file=sys.stderr)

if __name__ == "__main__":
    main()
