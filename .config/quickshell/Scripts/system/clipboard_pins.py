#!/usr/bin/env python3
"""Persistent Veyra clipboard snippets, independent of cliphist's rolling history."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any

DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local" / "share"))
STATE_FILE = DATA_HOME / "veyra" / "clipboard-pins.json"
MAX_PINS = 60
MAX_TEXT_BYTES = 512 * 1024


def load_pins() -> list[dict[str, Any]]:
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError, UnicodeError):
        return []
    if not isinstance(data, list):
        return []
    result = []
    for item in data:
        if not isinstance(item, dict):
            continue
        pin_id, text = item.get("id"), item.get("text")
        if isinstance(pin_id, str) and isinstance(text, str):
            result.append({"id": pin_id, "text": text, "pinnedAt": int(item.get("pinnedAt", 0) or 0)})
    return result


def save_pins(pins: list[dict[str, Any]]) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    # Pinned clips can contain private text, so keep the file user-readable only.
    fd, temporary = tempfile.mkstemp(prefix=".clipboard-pins-", dir=str(STATE_FILE.parent))
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(pins, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, STATE_FILE)
        try:
            os.chmod(STATE_FILE, 0o600)
        except OSError:
            pass
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def emit(value: Any) -> None:
    print(json.dumps(value, ensure_ascii=False), flush=True)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: clipboard_pins.py list|toggle|unpin ID|copy ID", file=sys.stderr)
        return 2
    action = argv[1]
    pins = load_pins()

    if action == "list":
        emit(pins)
        return 0

    if action == "toggle":
        # The snippet text arrives on stdin so private clipboard contents
        # never appear in /proc/<pid>/cmdline.
        text = sys.stdin.read()
        encoded = text.encode("utf-8")
        if not text.strip():
            emit({"ok": False, "message": "Blank text cannot be pinned."})
            return 1
        if len(encoded) > MAX_TEXT_BYTES:
            emit({"ok": False, "message": "This text is too large to pin (512 KiB limit)."})
            return 1
        existing = next((p for p in pins if p["text"] == text), None)
        if existing:
            pins = [p for p in pins if p["id"] != existing["id"]]
            save_pins(pins)
            emit({"ok": True, "pinned": False, "id": existing["id"]})
            return 0
        if len(pins) >= MAX_PINS:
            emit({"ok": False, "message": f"You can pin up to {MAX_PINS} snippets."})
            return 1
        entry = {"id": uuid.uuid4().hex, "text": text, "pinnedAt": int(time.time())}
        pins.insert(0, entry)
        save_pins(pins)
        emit({"ok": True, "pinned": True, "id": entry["id"]})
        return 0

    if action == "unpin":
        if len(argv) < 3:
            return 2
        before = len(pins)
        pins = [p for p in pins if p["id"] != argv[2]]
        if len(pins) != before:
            save_pins(pins)
        emit({"ok": True, "removed": len(pins) != before})
        return 0

    if action == "copy":
        if len(argv) < 3:
            return 2
        entry = next((p for p in pins if p["id"] == argv[2]), None)
        if entry is None:
            print("Pinned snippet not found.", file=sys.stderr)
            return 1
        try:
            result = subprocess.run(["wl-copy"], input=entry["text"].encode("utf-8"), timeout=8, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            print(f"Could not copy pinned snippet: {exc}", file=sys.stderr)
            return 1
        return result.returncode

    print(f"Unknown action: {action}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
