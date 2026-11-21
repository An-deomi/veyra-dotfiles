#!/usr/bin/env python3
"""Report whether a Proton VPN tunnel is actually active, not just tray-present."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from typing import Iterable


def run(args: list[str], timeout: float = 2.0) -> str:
    try:
        result = subprocess.run(
            args, capture_output=True, text=True, timeout=timeout, check=False
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout if result.returncode == 0 else ""


def split_nmcli_fields(line: str) -> list[str]:
    fields: list[str] = []
    current: list[str] = []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
    if escaped:
        current.append("\\")
    fields.append("".join(current))
    return [field.replace("\\:", ":").replace("\\\\", "\\") for field in fields]


def active_proton_profile(rows: Iterable[str]) -> bool:
    """Return true only for an active Proton server profile, not its kill switch."""
    exclusions = ("killswitch", "kill-switch", "kill switch", "leak-protection", "leak_protection", "block-internet")
    proton_names = ("protonvpn", "proton vpn", "proton-vpn")
    vpn_types = ("vpn", "wireguard", "tun", "ip-tunnel")
    for row in rows:
        if not row.strip():
            continue
        fields = split_nmcli_fields(row)
        if len(fields) < 3:
            continue
        name, connection_type, device = (fields[0].strip().lower(), fields[1].strip().lower(), fields[2].strip().lower())
        if any(token in name for token in exclusions):
            continue
        if any(token in name for token in proton_names) and (
            connection_type in vpn_types or device.startswith(("proton", "tun", "wg"))
        ):
            return True
    return False


def status_from_cli(text: str) -> bool | None:
    """Parse a CLI status only when it explicitly says connected/disconnected."""
    if not text.strip():
        return None
    normalized = text.lower()
    # Check a negative state first; 'disconnected' must never match 'connected'.
    if re.search(r"\b(disconnected|not connected|connection failed|no active connection)\b", normalized):
        return False
    if re.search(r"\b(status|state|vpn)\s*[:=]\s*connected\b", normalized):
        return True
    if re.search(r"^\s*connected\s*$", normalized, re.MULTILINE):
        return True
    return None


def detect_connected() -> bool:
    # Some Proton CLI builds know the app's state more accurately than NetworkManager.
    for command in (["protonvpn-cli", "status"], ["protonvpn", "status"]):
        output = run(list(command), timeout=2.5)
        parsed = status_from_cli(output)
        if parsed is not None:
            return parsed

    active = run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"])
    return active_proton_profile(active.splitlines())


def main() -> int:
    print(json.dumps({"connected": detect_connected()}), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
