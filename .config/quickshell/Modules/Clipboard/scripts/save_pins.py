#!/usr/bin/env python3
"""Atomically save Veyra's user-pinned text snippets with private permissions."""
from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: save_pins.py DESTINATION", file=sys.stderr)
        return 2

    destination = Path(sys.argv[1]).expanduser()
    try:
        parsed = json.load(sys.stdin)
        if not isinstance(parsed, list):
            raise ValueError("pin data must be a JSON array")
        clean: list[dict[str, object]] = []
        for item in parsed[:40]:
            if not isinstance(item, dict):
                continue
            item_id = str(item.get("itemId", ""))
            content = item.get("text", "")
            preview = item.get("preview", content)
            try:
                pinned_at = int(item.get("pinnedAt", 0))
            except (TypeError, ValueError):
                pinned_at = 0
            if not item_id or not isinstance(content, str):
                continue
            clean.append({
                "itemId": item_id,
                "text": content[:16000],
                "preview": str(preview)[:240],
                "pinnedAt": pinned_at,
            })

        destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix=".clipboard-pins-", dir=str(destination.parent))
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(clean, handle, ensure_ascii=False, separators=(",", ":"))
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, destination)
            os.chmod(destination, 0o600)
        finally:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"cannot save clipboard pins: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
