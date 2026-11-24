#!/usr/bin/env python3
"""Safe, targeted Hypridle timeout editor for Veyra's Settings UI.

Only edits timeout values in listener blocks whose active on-timeout command
can be confidently recognized as lock, DPMS-off, or system suspend. It never
creates/removes listener blocks or changes their commands.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path
from typing import Any

ACTIONS = ("lock", "screen_off", "suspend")
ACTION_LABELS = {
    "lock": "Lock screen",
    "screen_off": "Turn display off",
    "suspend": "Suspend system",
}


def emit(data: dict[str, Any], exit_code: int = 0) -> None:
    print(json.dumps(data, ensure_ascii=False))
    raise SystemExit(exit_code)


def uncomment(line: str) -> str:
    """Strip Hyprlang # comments while respecting single/double quotes."""
    quote = ""
    escaped = False
    for i, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\":
            escaped = True
            continue
        if quote:
            if char == quote:
                quote = ""
            continue
        if char in ("'", '"'):
            quote = char
        elif char == "#":
            return line[:i]
    return line


def brace_delta(code: str) -> int:
    quote = ""
    escaped = False
    delta = 0
    for char in code:
        if escaped:
            escaped = False
            continue
        if char == "\\":
            escaped = True
            continue
        if quote:
            if char == quote:
                quote = ""
            continue
        if char in ("'", '"'):
            quote = char
        elif char == "{":
            delta += 1
        elif char == "}":
            delta -= 1
    return delta


def process_argvs() -> list[list[str]]:
    found: list[list[str]] = []
    proc = Path("/proc")
    try:
        entries = list(proc.iterdir())
    except OSError:
        return found
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            if (entry / "comm").read_text(errors="replace").strip() != "hypridle":
                continue
            raw = (entry / "cmdline").read_bytes()
            argv = [part.decode(errors="replace") for part in raw.split(b"\0") if part]
            if argv and Path(argv[0]).name == "hypridle":
                found.append(argv)
        except (OSError, PermissionError):
            continue
    return found


def choose_config(argvs: list[list[str]]) -> Path:
    for argv in argvs:
        for idx, arg in enumerate(argv[:-1]):
            if arg in ("-c", "--config"):
                p = Path(os.path.expandvars(os.path.expanduser(argv[idx + 1])))
                if not p.is_absolute():
                    try:
                        cwd = Path(f"/proc/{next_pid_for_argv(argv)}/cwd").resolve()
                        p = cwd / p
                    except (StopIteration, OSError):
                        p = Path.cwd() / p
                return p
            if arg.startswith("--config="):
                return Path(os.path.expandvars(os.path.expanduser(arg.split("=", 1)[1])))
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg).expanduser() if xdg else Path.home() / ".config"
    return base / "hypr" / "hypridle.conf"


def next_pid_for_argv(argv: list[str]) -> int:
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            raw = (entry / "cmdline").read_bytes()
            candidate = [part.decode(errors="replace") for part in raw.split(b"\0") if part]
            if candidate == argv:
                return int(entry.name)
        except OSError:
            continue
    raise StopIteration


def variable_map(lines: list[str]) -> dict[str, str]:
    variables: dict[str, str] = {}
    for line in lines:
        code = uncomment(line)
        match = re.match(r"^\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", code)
        if match:
            variables[match.group(1)] = match.group(2)
    return variables


def expand_vars(command: str, variables: dict[str, str]) -> str:
    result = command
    for _ in range(4):
        changed = False
        for name, value in variables.items():
            new, count = re.subn(rf"\${re.escape(name)}\b", lambda _m, v=value: v, result)
            if count:
                changed = True
                result = new
        if not changed:
            break
    return result


def classify_command(command: str, variables: dict[str, str]) -> str | None:
    command = expand_vars(command, variables).lower()
    # Lock-session commands or recognizable Wayland lock applications.
    lock_patterns = (
        r"\bloginctl\s+lock-session\b",
        r"\bqs\s+ipc\s+call\s+lockscreen\s+lock\b",
        r"\b(?:hyprlock|swaylock|gtklock|waylock|betterlockscreen)\b",
        r"\b(loginctl\s+lock|lockscreen\.sh|lock_screen)\b",
    )
    if any(re.search(pattern, command) for pattern in lock_patterns):
        return "lock"
    if re.search(r"\bdpms\b", command) and re.search(r"\b(?:off|disable)\b", command):
        return "screen_off"
    if re.search(r"\bsystemctl\s+(?:suspend|hibernate|hybrid-sleep|suspend-then-hibernate)\b", command) or re.search(r"\bloginctl\s+(?:suspend|hibernate)\b", command) or re.search(r"\bzzz\b", command):
        return "suspend"
    return None


def parse_listeners(text: str) -> tuple[list[dict[str, Any]], dict[str, str]]:
    lines = text.splitlines(keepends=True)
    variables = variable_map(lines)
    blocks: list[dict[str, Any]] = []
    start: int | None = None
    depth = 0
    for i, line in enumerate(lines):
        code = uncomment(line)
        if start is None:
            if re.match(r"^\s*listener\s*\{", code):
                start = i
                depth = brace_delta(code)
                if depth == 0:
                    blocks.append(read_listener(lines, start, i, variables))
                    start = None
        else:
            depth += brace_delta(code)
            if depth == 0:
                blocks.append(read_listener(lines, start, i, variables))
                start = None
    return blocks, variables


def read_listener(lines: list[str], start: int, end: int, variables: dict[str, str]) -> dict[str, Any]:
    timeout_line: int | None = None
    timeout_value: int | None = None
    timeout_command = ""
    for i in range(start + 1, end):
        code = uncomment(lines[i])
        timeout_match = re.match(r"^\s*timeout\s*=\s*(\d+)\b", code)
        if timeout_match:
            timeout_line = i
            timeout_value = int(timeout_match.group(1))
        command_match = re.match(r"^\s*on-timeout\s*=\s*(.*?)\s*$", code)
        if command_match:
            timeout_command = command_match.group(1).strip()
    return {
        "start": start,
        "end": end,
        "timeout_line": timeout_line,
        "timeout": timeout_value,
        "command": timeout_command,
        "action": classify_command(timeout_command, variables),
    }


def inspect_config(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "ok": False,
        "config": str(path),
        "message": "",
        "actions": {key: {"found": False, "minutes": 0, "count": 0} for key in ACTIONS},
    }
    if not path.is_file():
        result["message"] = f"Hypridle config not found: {path}. The controls stay disabled rather than creating a new idle configuration."
        return result
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        result["message"] = f"Could not read {path}: {exc}"
        return result
    blocks, _ = parse_listeners(text)
    result["ok"] = True
    for action in ACTIONS:
        matches = [block for block in blocks if block["action"] == action]
        target = result["actions"][action]
        target["count"] = len(matches)
        target["found"] = len(matches) == 1 and matches[0]["timeout_line"] is not None and matches[0]["timeout"] is not None
        if target["found"]:
            target["minutes"] = max(1, int(round(matches[0]["timeout"] / 60)))
        elif len(matches) > 1:
            target["reason"] = "Multiple matching listeners; edit manually to avoid changing the wrong one."
        else:
            target["reason"] = "No recognizable listener found."
    present = [f"{ACTION_LABELS[a]}: {result['actions'][a]['minutes']} min" for a in ACTIONS if result["actions"][a]["found"]]
    missing = [ACTION_LABELS[a] for a in ACTIONS if not result["actions"][a]["found"]]
    summary = "; ".join(present) if present else "No supported timeout listeners were detected."
    if missing:
        summary += " Not detected: " + ", ".join(missing) + "."
    result["message"] = summary
    return result


def atomic_write(path: Path, content: str, original_mode: int) -> None:
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.veyra-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temp_name, original_mode)
        os.replace(temp_name, path)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass


def restart_hypridle(argvs: list[list[str]]) -> str:
    systemctl = shutil.which("systemctl")
    if systemctl:
        try:
            active = subprocess.run([systemctl, "--user", "is-active", "--quiet", "hypridle.service"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3).returncode == 0
        except (OSError, subprocess.SubprocessError):
            active = False
        if active:
            try:
                result = subprocess.run([systemctl, "--user", "restart", "hypridle.service"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=8)
                if result.returncode == 0:
                    return "Hypridle restarted through its user service."
                return "Settings saved, but the Hypridle user service could not restart. Restart hypridle manually to apply them."
            except (OSError, subprocess.SubprocessError):
                return "Settings saved, but the Hypridle user service could not restart. Restart hypridle manually to apply them."
    if not argvs:
        return "Settings saved. Hypridle is not running; changes will apply when it starts."
    binary = shutil.which("hypridle")
    if not binary:
        return "Settings saved, but the hypridle executable was not found for restart."
    argv = argvs[0]
    pids: list[int] = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid == os.getuid() and (entry / "comm").read_text(errors="replace").strip() == "hypridle":
                pids.append(int(entry.name))
        except OSError:
            continue
    try:
        for pid in pids:
            os.kill(pid, signal.SIGTERM)
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            alive = []
            for pid in pids:
                if Path(f"/proc/{pid}").exists():
                    alive.append(pid)
            if not alive:
                break
            time.sleep(0.05)
        # Preserve the running daemon's original command-line arguments, including -c.
        if not argv or Path(argv[0]).name != "hypridle":
            argv = [binary]
        restarted = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
        time.sleep(0.3)
        if restarted.poll() is not None:
            return "Settings saved, but Hypridle exited immediately after restart. Check hypridle's log/config syntax."
        return "Hypridle restarted with the updated configuration."
    except (OSError, subprocess.SubprocessError):
        return "Settings saved, but Hypridle could not be restarted. Restart it manually to apply them."


def apply_changes(path: Path, requested: dict[str, int], argvs: list[list[str]]) -> dict[str, Any]:
    status = inspect_config(path)
    if not status["ok"]:
        return status
    try:
        original = path.read_text(encoding="utf-8")
    except OSError as exc:
        status["ok"] = False
        status["message"] = f"Could not read {path}: {exc}"
        return status
    lines = original.splitlines(keepends=True)
    blocks, _variables = parse_listeners(original)
    to_update: dict[int, int] = {}
    changed: list[str] = []
    not_found: list[str] = []
    for action, minutes in requested.items():
        if action not in ACTIONS:
            continue
        matches = [block for block in blocks if block["action"] == action]
        if len(matches) != 1 or matches[0]["timeout_line"] is None or matches[0]["timeout"] is None:
            not_found.append(ACTION_LABELS[action])
            continue
        bounded_minutes = max(1, min(480, int(minutes)))
        to_update[matches[0]["timeout_line"]] = bounded_minutes * 60
        changed.append(ACTION_LABELS[action])
    if not to_update:
        status["ok"] = False
        status["message"] = "No timeout was changed. " + ("Could not safely identify: " + ", ".join(not_found) if not_found else "")
        return status
    backup_root = Path.home() / ".local" / "share" / "veyra-backups" / "hypridle-settings"
    backup_root.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup_path = backup_root / f"hypridle.conf.{stamp}.bak"
    try:
        shutil.copy2(path, backup_path)
        for idx, new_seconds in to_update.items():
            line = lines[idx]
            match = re.match(r"^(\s*timeout\s*=\s*)(\d+)([^\r\n]*)(\r?\n?)\Z", line, flags=re.IGNORECASE)
            if not match:
                status["ok"] = False
                status["message"] = f"Timeout line changed format unexpectedly; no config written. Backup: {backup_path}"
                return status
            lines[idx] = f"{match.group(1)}{new_seconds}{match.group(3)}{match.group(4)}"
        mode = path.stat().st_mode & 0o777
        atomic_write(path, "".join(lines), mode)
    except OSError as exc:
        status["ok"] = False
        status["message"] = f"Could not update {path}: {exc}. Backup: {backup_path}"
        return status
    restart_message = restart_hypridle(argvs)
    updated = inspect_config(path)
    updated["message"] = "Updated " + ", ".join(changed) + ". " + restart_message
    if not_found:
        updated["message"] += " Not changed because no unique listener was detected: " + ", ".join(not_found) + "."
    updated["backup"] = str(backup_path)
    return updated


def main() -> None:
    argvs = process_argvs()
    config = choose_config(argvs)
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        emit(inspect_config(config))
    if sys.argv[1] == "apply":
        requested: dict[str, int] = {}
        try:
            if len(sys.argv) > 2 and sys.argv[2] != "-":
                requested["lock"] = int(sys.argv[2])
            if len(sys.argv) > 3 and sys.argv[3] != "-":
                requested["screen_off"] = int(sys.argv[3])
            if len(sys.argv) > 4 and sys.argv[4] != "-":
                requested["suspend"] = int(sys.argv[4])
        except ValueError:
            emit({"ok": False, "config": str(config), "message": "Invalid timeout value supplied."}, 2)
        emit(apply_changes(config, requested, argvs), 0)
    emit({"ok": False, "config": str(config), "message": "Usage: hypridle_settings.py status | apply [lock_minutes|-] [screen_off_minutes|-] [suspend_minutes|-]"}, 2)


if __name__ == "__main__":
    main()
