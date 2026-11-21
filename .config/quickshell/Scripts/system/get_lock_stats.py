#!/usr/bin/env python3
"""Low-cost CPU, memory and uptime sampler for Veyra's lock screen.

This intentionally does not enumerate processes, inspect storage, detect GPUs,
or invoke nvidia-smi. The detailed System Monitor has its own on-demand sampler.
"""

from __future__ import annotations

import json
import sys
import time
from typing import Optional


def read_cpu_ticks() -> tuple[int, int]:
    """Return aggregate CPU (total, idle+iowait) ticks from /proc/stat."""
    try:
        with open("/proc/stat", "r", encoding="ascii") as handle:
            line = handle.readline()
        fields = line.split()
        if not fields or fields[0] != "cpu":
            return 0, 0
        ticks = [int(value) for value in fields[1:9]]
        if len(ticks) < 4:
            return 0, 0
        total = sum(ticks)
        idle = ticks[3] + (ticks[4] if len(ticks) > 4 else 0)
        return total, idle
    except (OSError, ValueError):
        return 0, 0


def read_memory() -> tuple[float, float]:
    """Return used and total memory in GiB, matching the detailed monitor."""
    values: dict[str, int] = {}
    try:
        with open("/proc/meminfo", "r", encoding="ascii") as handle:
            for line in handle:
                key, separator, rest = line.partition(":")
                if not separator:
                    continue
                parts = rest.split()
                if parts and key in ("MemTotal", "MemAvailable"):
                    values[key] = int(parts[0])
        total_kib = values["MemTotal"]
        available_kib = values["MemAvailable"]
        if total_kib <= 0:
            return 0.0, 0.0
        used_kib = max(0, total_kib - available_kib)
        return round(used_kib / (1024 * 1024), 1), round(
            total_kib / (1024 * 1024), 1
        )
    except (OSError, KeyError, ValueError):
        return 0.0, 0.0


def read_uptime() -> str:
    try:
        with open("/proc/uptime", "r", encoding="ascii") as handle:
            seconds = max(0, int(float(handle.read().split()[0])))
        days, remainder = divmod(seconds, 86400)
        hours, remainder = divmod(remainder, 3600)
        minutes = remainder // 60
        if days:
            return f"{days}d {hours}h"
        if hours:
            return f"{hours}h {minutes}m"
        return f"{minutes}m"
    except (OSError, ValueError, IndexError):
        return ""


def sample(previous: Optional[tuple[int, int]]) -> tuple[dict, tuple[int, int]]:
    current = read_cpu_ticks()
    usage = 0.0
    if previous is not None:
        total_delta = current[0] - previous[0]
        idle_delta = current[1] - previous[1]
        if total_delta > 0:
            usage = round(
                max(0.0, min(100.0, 100.0 * (total_delta - idle_delta) / total_delta)),
                1,
            )

    used_gib, total_gib = read_memory()
    return (
        {
            "system": {
                "cpu_usage": usage,
                "mem_used_gb": used_gib,
                "mem_total_gb": total_gib,
                "uptime": read_uptime(),
            }
        },
        current,
    )


def main() -> int:
    interval_ms = 6000
    daemon = False
    for argument in sys.argv[1:]:
        if argument == "--daemon":
            daemon = True
        else:
            try:
                interval_ms = max(1000, min(60000, int(argument)))
            except ValueError:
                print(f"Ignoring unrecognized argument: {argument}", file=sys.stderr)

    previous = read_cpu_ticks()
    if daemon:
        # Emit immediately so the lock screen never waits a full interval for
        # its first memory/uptime reading. The first CPU value is intentionally
        # 0 because a delta needs two samples.
        output, previous = sample(previous)
        print(json.dumps(output, separators=(",", ":")), flush=True)
        while True:
            time.sleep(interval_ms / 1000.0)
            output, previous = sample(previous)
            print(json.dumps(output, separators=(",", ":")), flush=True)
    else:
        time.sleep(0.2)
        output, _ = sample(previous)
        print(json.dumps(output, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
