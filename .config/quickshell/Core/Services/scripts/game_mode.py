#!/usr/bin/env python3
"""Safely apply and restore Veyra's temporary Game Mode power profile."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import stat
from pathlib import Path
from typing import Optional

sys.dont_write_bytecode = True

VALID_PROFILES = {"power-saver", "balanced", "performance"}


def _state_dir() -> Path:
    """Use the per-user runtime directory; keep the fallback private as well."""
    override = os.environ.get("VEYRA_GAME_MODE_STATE_DIR")
    if override:
        path = Path(override).expanduser()
    else:
        runtime = os.environ.get("XDG_RUNTIME_DIR")
        if runtime:
            path = Path(runtime) / "veyra"
        else:
            path = Path(tempfile.gettempdir()) / f"veyra-{os.getuid()}"
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        path.chmod(0o700)
    except OSError:
        pass
    return path


def _state_file() -> Path:
    return _state_dir() / "previous-power-profile.json"


def _legacy_state_file() -> Path:
    """Path used by older Veyra builds; read only during safe migration."""
    return Path(tempfile.gettempdir()) / "veyra_prev_power_profile"


def _read_legacy_saved_profile() -> Optional[str]:
    path = _legacy_state_file()
    try:
        details = path.lstat()
        if (
            not stat.S_ISREG(details.st_mode)
            or details.st_uid != os.getuid()
            or details.st_size > 128
            or stat.S_IMODE(details.st_mode) & 0o022
        ):
            return None
        profile = path.read_text(encoding="ascii").strip()
        return profile if profile in VALID_PROFILES else None
    except (OSError, UnicodeError):
        return None


def _run_powerprofilesctl(*arguments: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["powerprofilesctl", *arguments],
        capture_output=True,
        text=True,
        timeout=3,
        check=False,
    )


def _read_current_profile() -> tuple[Optional[str], Optional[str]]:
    try:
        result = _run_powerprofilesctl("get")
    except (OSError, subprocess.SubprocessError) as exc:
        return None, str(exc)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        return None, detail or "powerprofilesctl get failed"
    profile = result.stdout.strip()
    if profile not in VALID_PROFILES:
        return None, f"Unsupported current profile: {profile or '(empty)'}"
    return profile, None


def _read_saved_profile() -> Optional[str]:
    try:
        payload = json.loads(_state_file().read_text(encoding="utf-8"))
        profile = payload.get("profile") if isinstance(payload, dict) else None
        return profile if profile in VALID_PROFILES else None
    except (OSError, ValueError, TypeError):
        return None


def _save_profile(profile: str) -> None:
    path = _state_file()
    temp_path: Optional[str] = None
    try:
        fd, temp_path = tempfile.mkstemp(prefix=".profile-", dir=str(path.parent))
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump({"profile": profile, "uid": os.getuid()}, handle)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
        temp_path = None
    finally:
        if temp_path:
            try:
                os.unlink(temp_path)
            except OSError:
                pass


def _set_profile(profile: str) -> tuple[bool, Optional[str]]:
    if profile not in VALID_PROFILES:
        return False, f"Refusing unsupported power profile: {profile}"
    try:
        result = _run_powerprofilesctl("set", profile)
    except (OSError, subprocess.SubprocessError) as exc:
        return False, str(exc)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        return False, detail or f"powerprofilesctl set {profile} failed"
    return True, None


def get_status() -> dict:
    daemon_active = False
    try:
        result = subprocess.run(
            ["gamemoded", "-s"], capture_output=True, text=True, timeout=2, check=False
        )
        daemon_active = result.returncode == 0 and "is active" in result.stdout.lower()
    except (OSError, subprocess.SubprocessError):
        pass

    profile, error = _read_current_profile()
    status = {
        "gamemode_active": daemon_active,
        "power_profile": profile or "unknown",
    }
    if error:
        status["power_profile_error"] = error
    return status


def apply_mode() -> dict:
    current_profile, error = _read_current_profile()
    if current_profile is None:
        return {"status": "error", "error": error or "Power profiles are unavailable"}

    # Preserve the original profile across repeated apply requests while the
    # active profile remains Veyra's performance profile. If a prior run left
    # stale state and the current profile is no longer performance, refresh it.
    saved_profile = _read_saved_profile()
    # Migrate a valid old-format restore point only when the machine is still
    # in Game Mode's performance profile. This avoids reviving stale /tmp state
    # from a previous, already-ended session.
    if saved_profile is None and current_profile == "performance":
        legacy_path = _legacy_state_file()
        legacy_profile = _read_legacy_saved_profile()
        if legacy_profile is not None:
            try:
                _save_profile(legacy_profile)
                saved_profile = legacy_profile
                legacy_path.unlink(missing_ok=True)
            except OSError as exc:
                return {"status": "error", "error": f"Could not migrate previous profile: {exc}"}

    if saved_profile is None or current_profile != "performance":
        try:
            _save_profile(current_profile)
        except OSError as exc:
            return {"status": "error", "error": f"Could not save previous profile: {exc}"}

    success, set_error = _set_profile("performance")
    if not success:
        return {"status": "error", "error": set_error or "Could not enable performance profile"}
    return {"status": "applied", "previous_profile": current_profile}


def revert_mode() -> dict:
    state_path = _state_file()
    previous_profile = _read_saved_profile()
    if previous_profile is None:
        # Never guess 'balanced' when no trustworthy restore point exists.
        try:
            state_path.unlink(missing_ok=True)
        except OSError:
            pass
        return {"status": "skipped", "reason": "No valid saved power profile"}

    success, error = _set_profile(previous_profile)
    if not success:
        return {
            "status": "error",
            "restored_profile": previous_profile,
            "error": error or "Could not restore the previous power profile",
        }

    try:
        state_path.unlink(missing_ok=True)
    except OSError:
        pass
    return {"status": "reverted", "restored_profile": previous_profile}


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    actions = {
        "status": get_status,
        "apply": apply_mode,
        "revert": revert_mode,
    }
    if action not in actions or len(sys.argv) > 2:
        print(json.dumps({"status": "error", "error": "Usage: game_mode.py [status|apply|revert]"}))
        return 2
    try:
        result = actions[action]()
    except Exception as exc:  # keep IPC output predictable if the helper fails
        result = {"status": "error", "error": f"{type(exc).__name__}: {exc}"}
    print(json.dumps(result))
    return 0 if result.get("status") not in {"error"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
