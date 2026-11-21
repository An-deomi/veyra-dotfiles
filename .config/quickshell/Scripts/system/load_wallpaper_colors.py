#!/usr/bin/env python3
"""Load Veyra's dark/light wallpaper palettes as one JSON object."""
from __future__ import annotations
import json
import os
import sys
from pathlib import Path


def read_palette(path: Path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else None
    except (OSError, ValueError):
        return None


def main() -> int:
    cache_home = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")).expanduser()
    base = Path(sys.argv[1]) if len(sys.argv) > 1 else (cache_home / "quickshell")
    print(json.dumps({
        "dark": read_palette(base / "wallpaper_colorscheme_dark.json"),
        "light": read_palette(base / "wallpaper_colorscheme_light.json"),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
