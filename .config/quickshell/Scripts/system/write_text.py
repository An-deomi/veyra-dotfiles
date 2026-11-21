#!/usr/bin/env python3
"""Atomically write one line of text to a user-owned configuration file."""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: write_text.py PATH [MODE]", file=sys.stderr)
        return 2

    target = Path(sys.argv[1]).expanduser()
    mode = int(sys.argv[2], 8) if len(sys.argv) > 2 else 0o600
    content = sys.stdin.readline()
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)

    fd, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=target.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        os.chmod(target, mode)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
