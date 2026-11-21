#!/usr/bin/env python3
"""Prints JSON lines with CPU, temps, RAM, swap, network and NVIDIA GPU stats.

The first line comes after 0.2 s, then two lines per second.
The NVIDIA GPU is only queried with nvidia-smi while it is already awake
(runtime_status == active), at most once per second. If it is suspended we report
"off" and leave it alone, so this never keeps the dGPU powered and drains the battery.
"""
import glob
import json
import os
import shutil
import subprocess
import time

INTERVAL = 0.5
FIRST_INTERVAL = 0.2
GPU_EVERY = 1.0
PROCESS_EVERY = 2.0


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def cpu_times():
    vals = [int(x) for x in read("/proc/stat").splitlines()[0].split()[1:]]
    return sum(vals[:8]), vals[3] + vals[4]


def meminfo():
    info = {}
    for line in (read("/proc/meminfo") or "").splitlines():
        key, rest = line.split(":", 1)
        info[key] = int(rest.split()[0])
    used = (info["MemTotal"] - info["MemAvailable"]) // 1024
    swap_total = info.get("SwapTotal", 0) // 1024
    swap_used = (info.get("SwapTotal", 0) - info.get("SwapFree", 0)) // 1024
    return used, info["MemTotal"] // 1024, swap_used, swap_total


def network():
    rx = tx = 0
    for line in (read("/proc/net/dev") or "").splitlines()[2:]:
        name, data = line.split(":", 1)
        name = name.strip()
        if name == "lo" or name.startswith(("veth", "docker", "br-")):
            continue
        cols = data.split()
        rx += int(cols[0])
        tx += int(cols[8])
    return rx, tx


def cpu_temp():
    for d in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(d + "/name") == "coretemp":
            v = read(d + "/temp1_input")
            if v:
                return round(int(v) / 1000)
    for z in glob.glob("/sys/class/thermal/thermal_zone*"):
        if read(z + "/type") == "x86_pkg_temp":
            v = read(z + "/temp")
            if v:
                return round(int(v) / 1000)
    return None



def disk_usage():
    """Return usage for the user's home filesystem in MiB."""
    try:
        total, used, _free = shutil.disk_usage(os.path.expanduser("~"))
        return used // (1024 * 1024), total // (1024 * 1024)
    except OSError:
        return None, None


def process_snapshot():
    """Read process CPU ticks and resident memory directly from /proc."""
    snapshot = {}
    page_kb = os.sysconf("SC_PAGE_SIZE") // 1024
    for stat_path in glob.glob("/proc/[0-9]*/stat"):
        try:
            raw = read(stat_path)
            if not raw:
                continue
            # comm is parenthesized and may itself contain spaces or parentheses.
            close = raw.rfind(")")
            if close < 0:
                continue
            pid = int(raw[:raw.find(" ")])
            name = raw[raw.find("(") + 1:close][:22]
            fields = raw[close + 1:].split()  # Starts at field 3 (state).
            ticks = int(fields[11]) + int(fields[12])  # utime + stime (14 + 15).
            statm = read(f"/proc/{pid}/statm")
            resident_kb = int(statm.split()[1]) * page_kb if statm else 0
            snapshot[pid] = {"name": name, "ticks": ticks, "rss": resident_kb}
        except (OSError, ValueError, IndexError, ProcessLookupError):
            continue
    return snapshot


def top_processes(previous, current, total_cpu_delta, total_memory_kb, limit=5):
    """Calculate current process CPU as a share of total machine capacity."""
    rows = []
    cpu_delta = max(1, total_cpu_delta)
    memory_total = max(1, total_memory_kb)
    for pid, item in current.items():
        old = previous.get(pid)
        if old is None:
            continue
        delta = max(0, item["ticks"] - old["ticks"])
        rows.append({
            "pid": pid,
            "name": item["name"],
            "cpu": round(100.0 * delta / cpu_delta, 1),
            "mem": round(100.0 * item["rss"] / memory_total, 1),
        })
    rows.sort(key=lambda row: row["cpu"], reverse=True)
    return rows[:limit]


def uptime_seconds():
    try:
        return int(float(read("/proc/uptime").split()[0]))
    except (AttributeError, ValueError, IndexError):
        return 0


def find_nvidia():
    for d in glob.glob("/sys/bus/pci/devices/*"):
        if read(d + "/vendor") == "0x10de" and (read(d + "/class") or "").startswith("0x03"):
            return d
    return None


def nvidia_query():
    try:
        out = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=3,
        ).stdout.strip().splitlines()[0]
        util, temp, used, total = [int(x) for x in out.split(",")]
        return {"state": "on", "util": util, "temp": temp, "memUsed": used, "memTotal": total}
    except Exception:
        return None


def main():
    dev = find_nvidia()
    t1, i1 = cpu_times()
    rx1, tx1 = network()
    n1 = time.monotonic()
    gpu = None
    gpu_at = 0.0
    processes = []
    process_at = 0.0
    previous_processes = process_snapshot()
    previous_process_cpu = t1
    time.sleep(FIRST_INTERVAL)  # short first interval: the popup gets numbers right away
    while True:
        t2, i2 = cpu_times()
        rx2, tx2 = network()
        n2 = time.monotonic()
        dt, di = t2 - t1, i2 - i1
        elapsed = max(n2 - n1, 0.001)

        if dev is not None:
            status = read(dev + "/power/runtime_status")
            if status not in (None, "active"):
                gpu = {"state": "off"}
            elif gpu is None or gpu.get("state") == "off" or n2 - gpu_at >= GPU_EVERY:
                gpu = nvidia_query()
                gpu_at = n2
        used, total, swap_used, swap_total = meminfo()
        disk_used, disk_total = disk_usage()
        if n2 - process_at >= PROCESS_EVERY:
            current_processes = process_snapshot()
            processes = top_processes(previous_processes, current_processes, t2 - previous_process_cpu, total * 1024)
            previous_processes = current_processes
            previous_process_cpu = t2
            process_at = n2
        try:
            load_avg = [round(x, 2) for x in os.getloadavg()]
        except (AttributeError, OSError):
            load_avg = []

        line = json.dumps(
            {
                "cpu": round(100 * (dt - di) / dt) if dt > 0 else 0,
                "cpuTemp": cpu_temp(),
                "ramUsed": used,
                "ramTotal": total,
                "swapUsed": swap_used,
                "swapTotal": swap_total,
                "diskUsed": disk_used,
                "diskTotal": disk_total,
                "uptime": uptime_seconds(),
                "load": load_avg,
                "processes": processes,
                "rx": max(rx2 - rx1, 0) / elapsed,
                "tx": max(tx2 - tx1, 0) / elapsed,
                "gpu": gpu,
            }
        )
        try:
            print(line, flush=True)
        except (BrokenPipeError, OSError):
            return
        t1, i1, rx1, tx1, n1 = t2, i2, rx2, tx2, n2
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
