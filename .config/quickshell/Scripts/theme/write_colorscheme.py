#!/usr/bin/env python3
"""Atomically save Veyra's live colorscheme JSON supplied by Quickshell."""
import json
import os
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True

from xdg_paths import state_home


def main():
    if len(sys.argv) < 2:
        print("Expected serialized colorscheme JSON.", file=sys.stderr)
        return 2
    try:
        data = json.loads(sys.argv[1])
    except (TypeError, ValueError) as exc:
        print(f"Invalid colorscheme JSON: {exc}", file=sys.stderr)
        return 2
    if not isinstance(data, dict) or not all(key in data for key in ("bg", "fg", "accent")):
        print("Colorscheme is missing required palette values.", file=sys.stderr)
        return 2

    target_dir = state_home() / "veyra"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / "colorscheme.json"
    fd, temporary = tempfile.mkstemp(prefix=".colorscheme-", suffix=".tmp", dir=target_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, separators=(",", ":"))
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        try:
            dir_fd = os.open(target_dir, os.O_RDONLY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError:
            pass
    finally:
        try:
            if os.path.exists(temporary):
                os.unlink(temporary)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
