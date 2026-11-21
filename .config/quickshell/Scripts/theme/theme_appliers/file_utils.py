"""Small safe file-writing helpers for generated theme integrations."""
from __future__ import annotations

import os
import stat
import tempfile
from pathlib import Path


def atomic_write_text(path: Path | str, content: str) -> None:
    """Replace a config file atomically while preserving its permission bits.

    Symlinks are rejected rather than silently replaced: these appliers should
    not change the meaning of a user's linked configuration file.
    """
    target = Path(path).expanduser()
    target.parent.mkdir(parents=True, exist_ok=True)

    if target.is_symlink():
        raise ValueError(f"refusing to replace symlinked config file: {target}")

    try:
        mode = stat.S_IMODE(target.stat().st_mode)
    except FileNotFoundError:
        mode = 0o600

    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{target.name}.", suffix=".tmp", dir=str(target.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, target)

        # Persist the directory entry where supported.
        try:
            directory_fd = os.open(target.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        except OSError:
            pass
    except BaseException:
        try:
            os.unlink(temporary_name)
        except OSError:
            pass
        raise
