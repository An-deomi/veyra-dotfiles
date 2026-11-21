#!/usr/bin/env python3
"""Sample receive/transmit speed on the active default-route interface.

Emits one JSON object per second with downloadBps and uploadBps. Reads only
/sys network counters and does not require elevated permissions.
"""
import json
import subprocess
import time

INTERVAL = 1.0
ROUTE_CHECK_INTERVAL = 10.0


def route_interface():
    try:
        result = subprocess.run(
            ["ip", "route", "get", "1.1.1.1"],
            capture_output=True,
            text=True,
            timeout=1,
            check=True,
        )
        fields = result.stdout.split()
        if "dev" in fields:
            return fields[fields.index("dev") + 1]
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def read_counters(interface):
    if not interface:
        return None
    try:
        with open(f"/sys/class/net/{interface}/statistics/rx_bytes") as f:
            received = int(f.read().strip())
        with open(f"/sys/class/net/{interface}/statistics/tx_bytes") as f:
            transmitted = int(f.read().strip())
        return received, transmitted
    except (OSError, ValueError):
        return None


def emit(download, upload):
    print(json.dumps({
        "downloadBps": round(max(0.0, download)),
        "uploadBps": round(max(0.0, upload)),
    }), flush=True)


def main():
    interface = route_interface()
    previous = read_counters(interface)
    previous_time = time.monotonic()
    next_route_check = previous_time + ROUTE_CHECK_INTERVAL

    while True:
        time.sleep(INTERVAL)
        now = time.monotonic()

        if now >= next_route_check:
            new_interface = route_interface()
            next_route_check = now + ROUTE_CHECK_INTERVAL
            if new_interface != interface:
                interface = new_interface
                previous = read_counters(interface)
                previous_time = now
                emit(0, 0)
                continue

        current = read_counters(interface)
        elapsed = max(now - previous_time, 0.001)

        if current is not None and previous is not None:
            download = max(0, current[0] - previous[0]) / elapsed
            upload = max(0, current[1] - previous[1]) / elapsed
        else:
            download = upload = 0

        emit(download, upload)
        if current is not None:
            previous = current
        previous_time = now


if __name__ == "__main__":
    main()
