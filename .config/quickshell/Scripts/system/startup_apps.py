#!/usr/bin/env python3
"""List and toggle the current user's XDG autostart desktop entries."""

import json
import os
import re
import sys
import tempfile
from pathlib import Path

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()
AUTOSTART_DIR = CONFIG_HOME / "autostart"
SAFE_ID = re.compile(r"^[A-Za-z0-9_.-]+\.desktop$")


def read_desktop_entry(path: Path) -> dict:
    values = {}
    in_entry = False
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            in_entry = line == "[Desktop Entry]"
            continue
        if not in_entry or not line or line.startswith(("#", ";")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()

    hidden = values.get("Hidden", "false").lower() == "true"
    gnome_enabled = values.get("X-GNOME-Autostart-enabled", "true").lower() != "false"
    return {
        "id": path.name,
        "name": values.get("Name", path.stem),
        "comment": values.get("Comment", ""),
        "exec": values.get("Exec", ""),
        "enabled": not hidden and gnome_enabled,
        "icon": values.get("Icon", ""),
    }


def list_entries() -> list[dict]:
    if not AUTOSTART_DIR.is_dir():
        return []
    entries = []
    for path in sorted(AUTOSTART_DIR.glob("*.desktop"), key=lambda p: p.name.casefold()):
        try:
            if path.is_file():
                entries.append(read_desktop_entry(path))
        except OSError:
            continue
    return entries


def update_key(lines: list[str], key: str, value: str | None) -> list[str]:
    section_start = None
    section_end = len(lines)
    for index, line in enumerate(lines):
        if line.strip() == "[Desktop Entry]":
            section_start = index
            break
    if section_start is None:
        raise ValueError("The file has no [Desktop Entry] section")

    for index in range(section_start + 1, len(lines)):
        if lines[index].strip().startswith("[") and lines[index].strip().endswith("]"):
            section_end = index
            break

    before = lines[:section_start + 1]
    section = lines[section_start + 1:section_end]
    after = lines[section_end:]
    updated_section = []
    found = False
    for line in section:
        if line.strip().startswith(key + "="):
            if not found and value is not None:
                updated_section.append(f"{key}={value}")
            found = True
        else:
            updated_section.append(line)

    if value is not None and not found:
        updated_section.append(f"{key}={value}")
    return before + updated_section + after


def set_enabled(entry_id: str, enabled: bool) -> dict:
    if not SAFE_ID.fullmatch(entry_id):
        raise ValueError("Invalid startup entry name")
    path = (AUTOSTART_DIR / entry_id).resolve()
    if path.parent != AUTOSTART_DIR.resolve() or not path.is_file():
        raise FileNotFoundError("Startup entry was not found")

    original = path.read_text(encoding="utf-8", errors="replace")
    lines = original.splitlines()
    if enabled:
        lines = update_key(lines, "Hidden", None)
        lines = update_key(lines, "X-GNOME-Autostart-enabled", "true")
    else:
        lines = update_key(lines, "Hidden", "true")
        lines = update_key(lines, "X-GNOME-Autostart-enabled", "false")

    payload = "\n".join(lines) + "\n"
    mode = path.stat().st_mode & 0o777
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(AUTOSTART_DIR))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
        os.chmod(temp_name, mode)
        os.replace(temp_name, path)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise

    return {"ok": True, "message": f"{'Enabled' if enabled else 'Disabled'} {entry_id}"}


def main() -> int:
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "list":
            print(json.dumps(list_entries()))
            return 0
        if len(sys.argv) == 4 and sys.argv[1] == "set":
            enabled_arg = sys.argv[3].strip().lower()
            if enabled_arg not in {"true", "false"}:
                raise ValueError("Expected true or false")
            print(json.dumps(set_enabled(sys.argv[2], enabled_arg == "true")))
            return 0
        print(json.dumps({"ok": False, "message": "Usage: startup_apps.py list | set ENTRY.desktop true|false"}))
        return 2
    except (OSError, ValueError) as error:
        print(json.dumps({"ok": False, "message": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
