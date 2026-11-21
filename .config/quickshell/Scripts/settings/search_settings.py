#!/usr/bin/env python3
"""Index every Veyra Settings control label so the sidebar can search them.

The sidebar used to filter navigation labels only, so searching for "radius" or
"keyboard" found nothing even though those controls exist. This prints one JSON
line: a list of {label, page, pageTitle} matching the query.
"""

import json
import re
import sys
from pathlib import Path

# Directory under Modules/Settings -> (tab id, page title). Mirrors the
# pageComponents order in Modules/Settings/Settings.qml.
PAGES = {
    "PersonalizationSettings": (0, "Appearance"),
    "BarSettings": (1, "Shell"),
    "WindowSettings": (2, "Hyprland"),
    "IntegrationsSettings": (4, "Integrations & Apps"),
    "MouseSettings": (5, "Mouse & Touchpad"),
    "InputAndClipboardSettings": (6, "Keyboard & Clipboard"),
    "SystemInfo": (7, "About System"),
    "WallpaperSettings": (8, "Wallpaper"),
    "LockScreenSettings": (9, "Lock Screen"),
    "NotificationsSettings": (10, "Notifications"),
    "ScreenCaptureSettings": (11, "Screen Capture"),
    "DefaultAppsSettings": (12, "Default Apps"),
    "PowerSettings": (13, "Power & Battery"),
    "StartupSettings": (14, "Startup Applications"),
    "HyprlandTools": (16, "Window Rules & Displays"),
    "ThemeStudio": (17, "Theme Studio"),
}

LABEL_LINE = re.compile(r'^\s*label:\s*"([^"]{1,80})"')
DESC_LINE = re.compile(r'^\s*description:\s*"([^"]{1,200})"')
TITLE_LINE = re.compile(r'^\s*title:\s*"([^"]{1,80})"')
MAX_RESULTS = 40


def main():
    query = sys.argv[1].strip().lower() if len(sys.argv) > 1 else ""
    if not query:
        print("[]")
        return

    root = Path(__file__).resolve().parents[2] / "Modules" / "Settings"
    results = []
    seen = set()

    for directory, (page_id, page_title) in PAGES.items():
        page_dir = root / directory
        if not page_dir.is_dir():
            continue
        for path in sorted(page_dir.rglob("*.qml")):
            try:
                text = path.read_text(encoding="utf-8")
            except OSError:
                continue

            # Labels can be literals or JS expressions; also match a row's
            # description and report the label that precedes it.
            current = None
            group = ""
            for line in text.splitlines():
                title_match = TITLE_LINE.match(line)
                if title_match:
                    group = title_match.group(1)
                    continue

                label_match = LABEL_LINE.match(line)
                if label_match:
                    current = label_match.group(1)
                    matched = query in current.lower()
                else:
                    desc_match = DESC_LINE.match(line)
                    matched = bool(
                        desc_match and current and query in desc_match.group(1).lower()
                    )

                if not matched or not current:
                    continue

                # Group context disambiguates repeated labels like "Height".
                key = (page_id, group, current)
                if key in seen:
                    continue
                seen.add(key)
                results.append(
                    {
                        "label": current,
                        "group": group,
                        "page": page_id,
                        "pageTitle": page_title,
                    }
                )

    results.sort(key=lambda entry: (entry["pageTitle"], entry["group"], entry["label"]))
    print(json.dumps(results[:MAX_RESULTS]))


if __name__ == "__main__":
    main()
