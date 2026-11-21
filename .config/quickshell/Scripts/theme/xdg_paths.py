"""Small shared helpers for XDG-compliant Veyra theme paths."""
from pathlib import Path
import os


def config_home(home=None) -> Path:
    base = Path(home or Path.home()).expanduser()
    return Path(os.environ.get("XDG_CONFIG_HOME") or (base / ".config")).expanduser()


def data_home(home=None) -> Path:
    base = Path(home or Path.home()).expanduser()
    return Path(os.environ.get("XDG_DATA_HOME") or (base / ".local/share")).expanduser()


def cache_home(home=None) -> Path:
    base = Path(home or Path.home()).expanduser()
    return Path(os.environ.get("XDG_CACHE_HOME") or (base / ".cache")).expanduser()


def state_home(home=None) -> Path:
    base = Path(home or Path.home()).expanduser()
    return Path(os.environ.get("XDG_STATE_HOME") or (base / ".local/state")).expanduser()
