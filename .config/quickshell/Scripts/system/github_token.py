#!/usr/bin/env python3
"""Read, store, or clear the Veyra GitHub token without putting it in argv."""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ATTRS = ["application", "veyra", "purpose", "github-api"]


def fallback_path() -> Path:
    state_home = Path(os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local/state"))
    return state_home / "veyra" / "github_token"


def keyring_get() -> str | None:
    if not shutil.which("secret-tool"):
        return None
    try:
        result = subprocess.run(
            ["secret-tool", "lookup", *ATTRS],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode == 0 and result.stdout.strip():
        return result.stdout.strip()
    return None


def load() -> str:
    token = keyring_get()
    if token:
        return token
    try:
        return fallback_path().read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def store(token: str) -> None:
    if shutil.which("secret-tool"):
        try:
            result = subprocess.run(
                ["secret-tool", "store", "--label=Veyra GitHub API token", *ATTRS],
                input=token + "\n",
                capture_output=True,
                text=True,
                timeout=8,
            )
            if result.returncode == 0:
                return
        except (OSError, subprocess.TimeoutExpired):
            # Use the private XDG state file when Secret Service is unavailable.
            pass

    target = fallback_path()
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(prefix=".github-token.", dir=target.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(token + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        os.chmod(target, 0o600)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def clear() -> None:
    if shutil.which("secret-tool"):
        try:
            subprocess.run(
                ["secret-tool", "clear", *ATTRS],
                capture_output=True,
                text=True,
                timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired):
            # The private file is still cleared below; callers are not blocked
            # by an unavailable Secret Service daemon.
            pass
    try:
        fallback_path().unlink()
    except FileNotFoundError:
        pass


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"get", "set", "clear"}:
        print("usage: github_token.py get|set|clear", file=sys.stderr)
        return 2
    action = sys.argv[1]
    if action == "get":
        print(load())
    elif action == "set":
        token = sys.stdin.readline().strip()
        if token:
            store(token)
        else:
            clear()
    else:
        clear()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
