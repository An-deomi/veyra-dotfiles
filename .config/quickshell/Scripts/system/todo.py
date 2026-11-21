#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import tempfile
from datetime import date

DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.join(os.path.expanduser("~"), ".local/share"))
PATH = os.path.join(DATA_HOME, "veyra/todo.json")


def clean(data):
    out = []
    if isinstance(data, list):
        for t in data:
            if not isinstance(t, dict):
                continue

            text = str(t.get("text", "")).strip()
            if not text:
                continue

            due_date = str(t.get("dueDate", "") or "").strip()
            if due_date:
                try:
                    if (
                        len(due_date) != 10
                        or due_date[4] != "-"
                        or due_date[7] != "-"
                    ):
                        raise ValueError("Expected YYYY-MM-DD")
                    date.fromisoformat(due_date)
                except ValueError:
                    due_date = ""

            priority = str(t.get("priority", "normal")).lower()
            if priority not in ("high", "normal", "low"):
                priority = "normal"

            out.append({
                "text": text,
                "done": bool(t.get("done", False)),
                "dueDate": due_date,
                "priority": priority,
            })
    return out


def load():
    try:
        with open(PATH, encoding="utf-8") as f:
            print(json.dumps(clean(json.load(f)), ensure_ascii=False))
    except Exception:
        print("[]")


def save(raw):
    try:
        out = clean(json.loads(raw))
    except ValueError as exc:
        print(json.dumps({"success": False, "error": f"invalid task JSON: {exc}"}))
        return
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(PATH), suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    os.replace(tmp, PATH)
    print(json.dumps({"success": True}))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "load":
        load()
    elif a and a[0] == "save":
        # Task JSON arrives on stdin so private to-do text never shows up
        # in /proc/<pid>/cmdline.
        save(sys.stdin.read())
    else:
        print("[]")
