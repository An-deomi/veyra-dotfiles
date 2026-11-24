"""Small shared helpers for XDG-compliant Veyra theme paths."""
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True


def _passwd_home() -> Path | None:
    try:
        import pwd

        return Path(pwd.getpwuid(os.getuid()).pw_dir).resolve(strict=False)
    except (ImportError, KeyError, OSError):
        return None


def _resolve_xdg(env_key: str, default_rel: str, home=None) -> Path:
    base = Path(home or os.environ.get("HOME") or Path.home()).expanduser()
    raw_xdg = os.environ.get(env_key)
    if raw_xdg:
        xdg_path = Path(raw_xdg).expanduser()
        pw_home = _passwd_home()
        if pw_home is not None:
            base_resolved = base.resolve(strict=False)
            xdg_resolved = xdg_path.resolve(strict=False)
            # Ignore host-session XDG_*_HOME values rooted under the passwd home
            # when an isolated HOME override (e.g. HOME=/tmp/...) is in effect.
            if (
                base_resolved != pw_home
                and xdg_resolved.is_relative_to(pw_home)
                and not xdg_resolved.is_relative_to(base_resolved)
            ):
                return base / default_rel
        return xdg_path
    return base / default_rel


def config_home(home=None) -> Path:
    return _resolve_xdg("XDG_CONFIG_HOME", ".config", home)


def data_home(home=None) -> Path:
    return _resolve_xdg("XDG_DATA_HOME", ".local/share", home)


def cache_home(home=None) -> Path:
    return _resolve_xdg("XDG_CACHE_HOME", ".cache", home)


def state_home(home=None) -> Path:
    return _resolve_xdg("XDG_STATE_HOME", ".local/state", home)


def is_live_session(home=None) -> bool:
    """Return True only when targeting the current user's live GUI session."""
    if os.environ.get("VEYRA_SAFE_TEST") == "1":
        return False
    if not (os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY")):
        return False
    pw_home = _passwd_home()
    if pw_home is not None:
        target = Path(home or os.environ.get("HOME") or Path.home()).expanduser().resolve(strict=False)
        if target != pw_home:
            return False
    return True
