#!/usr/bin/env python3
"""Clear cliphist entries except those backing Veyra's pinned snippets.

Reads a JSON array of {"itemId": "..."} objects from stdin. Fails closed if
that input or `cliphist list` cannot be read, so unknown pin state never causes
an accidental full wipe.
"""
from __future__ import annotations

import json
import subprocess
import sys
from typing import Any


def main() -> int:
    try:
        pin_data: Any = json.load(sys.stdin)
        if not isinstance(pin_data, list):
            raise ValueError("pinned item input is not a JSON array")
        pinned_ids: set[str] = set()
        for entry in pin_data:
            if isinstance(entry, dict) and entry.get("itemId") is not None:
                pinned_ids.add(str(entry["itemId"]))

        history = subprocess.run(
            ["cliphist", "list"], check=False, capture_output=True, text=True
        )
        if history.returncode != 0:
            message = history.stderr.strip() or "cliphist list failed"
            print(message, file=sys.stderr)
            return history.returncode or 1

        to_delete: list[str] = []
        history_count = 0
        for line in history.stdout.splitlines():
            if not line:
                continue
            item_id, sep, _rest = line.partition("\t")
            if not sep:
                # Ignore lines the UI itself would not parse either.
                continue
            history_count += 1
            if item_id not in pinned_ids:
                to_delete.append(line)

        deleted = 0
        for line in to_delete:
            result = subprocess.run(
                ["cliphist", "delete"],
                input=line + "\n",
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                message = result.stderr.strip() or f"cliphist delete failed for item {line.partition(chr(9))[0]}"
                print(message, file=sys.stderr)
                return result.returncode or 1
            deleted += 1

        kept = history_count - deleted
        print(f"Cleared {deleted} unpinned item(s); kept {kept} pinned item(s).")
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Clipboard was not cleared to protect pinned items: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
