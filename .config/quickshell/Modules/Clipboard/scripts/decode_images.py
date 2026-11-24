#!/usr/bin/env python3
"""Decode cliphist image entries into a private per-user cache directory.

Usage: decode_images.py CACHE_DIR [cliphist_id ...]

The cache directory is created with 0700 and each decoded image is written
0600. cliphist ids must be decimal strings; anything else is skipped.
"""
import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: decode_images.py CACHE_DIR [cliphist_id ...]", file=sys.stderr)
        return 2

    cache_dir = Path(os.path.expanduser(sys.argv[1]))
    cache_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        os.chmod(cache_dir, 0o700)
    except OSError:
        pass

    decoded = 0
    for raw_id in sys.argv[2:]:
        if not raw_id.isdigit():
            continue
        target = cache_dir / f"{raw_id}.png"
        if target.exists():
            continue
        try:
            with open(target, "xb") as handle:
                os.chmod(target, 0o600)
                result = subprocess.run(
                    ["cliphist", "decode", raw_id],
                    stdout=handle,
                    stderr=subprocess.DEVNULL,
                    timeout=10,
                )
            if result.returncode != 0:
                target.unlink(missing_ok=True)
            else:
                decoded += 1
        except (OSError, subprocess.SubprocessError):
            target.unlink(missing_ok=True)

    print(decoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
