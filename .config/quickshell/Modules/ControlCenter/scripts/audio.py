#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import subprocess


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5)
    except Exception:
        return None


def pj(args):
    r = run(["pactl", "--format=json"] + args)
    if r is None or r.returncode != 0:
        return []
    try:
        d = json.loads(r.stdout)
        return d if isinstance(d, list) else []
    except Exception:
        return []


def pct(vol):
    try:
        for ch in vol.values():
            return int(str(ch.get("value_percent", "0")).strip().rstrip("%"))
    except Exception:
        pass
    return 0


def state(mode):
    out = mode == "out"
    devices = []
    for d in pj(["list", "sinks" if out else "sources"]):
        name = d.get("name", "")
        if not out and name.endswith(".monitor"):
            continue
        devices.append({"id": d.get("index"), "name": name, "desc": d.get("description") or name})
    r = run(["pactl", "get-default-sink" if out else "get-default-source"])
    default = r.stdout.strip() if (r is not None and r.returncode == 0) else ""
    streams = []
    for s in pj(["list", "sink-inputs" if out else "source-outputs"]):
        props = s.get("properties") or {}
        media = props.get("media.name", "")
        if media == "Peak detect":
            continue
        app = props.get("application.name") or props.get("application.process.binary") or "Unknown app"
        streams.append(
            {
                "id": s.get("index"),
                "app": app,
                "media": "" if media == app else media,
                "device": s.get("sink" if out else "source"),
                "volume": max(0, min(150 if out else 100, pct(s.get("volume") or {}))),
                "muted": bool(s.get("mute", False)),
            }
        )
    print(json.dumps({"devices": devices, "default": default, "streams": streams}, ensure_ascii=False))


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == "state" and a[1] in ("out", "in"):
        state(a[1])
    else:
        print("{}")
