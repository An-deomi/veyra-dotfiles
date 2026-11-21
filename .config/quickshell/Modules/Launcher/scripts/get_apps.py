#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import configparser
import json
import os
import re
import shutil
from pathlib import Path

ALWAYS_SHOW = {"blueman-adapters", "org.kde.plasma.emojier"}

FIELD_CODE = re.compile(r"\s+%[fFuUdDnNickvm](?=\s|$)")
CURRENT_DESKTOPS = [d for d in os.environ.get("XDG_CURRENT_DESKTOP", "").split(":") if d]


def split_list(value):
    return [v.strip() for v in value.split(";") if v.strip()]


def clean_exec(raw):
    # Drop standalone field codes (%u, %F, ...) but keep every other arg and its quoting.
    return FIELD_CODE.sub("", raw).strip()


def shown_here(entry):
    only = split_list(entry.get("OnlyShowIn", ""))
    not_in = split_list(entry.get("NotShowIn", ""))
    if only and not any(d in only for d in CURRENT_DESKTOPS):
        return False
    if any(d in not_in for d in CURRENT_DESKTOPS):
        return False
    return True


def try_exec_ok(entry):
    t = entry.get("TryExec", "").strip()
    if not t:
        return True
    if os.path.isabs(t):
        return os.access(t, os.X_OK)
    return shutil.which(t) is not None


def get_apps():
    apps = []
    seen_ids = set()
    seen_keys = set()

    # Prefer user-local application entries over system entries.
    paths = [
        Path.home() / ".local" / "share" / "applications",
        Path.home() / ".local" / "share" / "flatpak" / "exports" / "share" / "applications",
    ]
    xdg_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    paths.extend(Path(p) / "applications" for p in xdg_dirs)
    paths.append(Path("/var/lib/flatpak/exports/share/applications"))

    for d in paths:
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.desktop")):
            if f.stem in seen_ids:
                continue
            seen_ids.add(f.stem)
            try:
                config = configparser.ConfigParser(
                    interpolation=None, strict=False, delimiters=("=",)
                )
                config.read(f, encoding="utf-8")
                if "Desktop Entry" not in config:
                    continue
                entry = config["Desktop Entry"]

                if entry.get("Type", "Application") != "Application":
                    continue
                if (
                    entry.get("NoDisplay", "false").lower() == "true"
                    or entry.get("Hidden", "false").lower() == "true"
                    or (f.stem not in ALWAYS_SHOW and not shown_here(entry))
                    or not try_exec_ok(entry)
                ):
                    continue

                name = entry.get("Name", "").strip()
                exec_cmd = clean_exec(entry.get("Exec", "").strip())
                if not name or not exec_cmd:
                    continue

                key = (name.lower(), exec_cmd)
                if key in seen_keys:
                    continue
                seen_keys.add(key)

                actions = []
                for ak in split_list(entry.get("Actions", "")):
                    group = f"Desktop Action {ak}"
                    if group in config:
                        a_name = config[group].get("Name", "").strip()
                        a_exec = clean_exec(config[group].get("Exec", "").strip())
                        if a_name and a_exec:
                            actions.append({"name": a_name, "exec": a_exec})

                apps.append(
                    {
                        "id": f.stem,
                        "name": name,
                        "exec": exec_cmd,
                        "icon": entry.get("Icon", "").replace('"', "").strip(),
                        "terminal": entry.get("Terminal", "false").lower() == "true",
                        "actions": actions,
                        "categories": split_list(entry.get("Categories", "")),
                        "comment": entry.get("Comment", "").strip(),
                        "genericName": entry.get("GenericName", "").strip(),
                        "keywords": split_list(entry.get("Keywords", "")),
                    }
                )
            except Exception:
                continue

    return sorted(apps, key=lambda x: x["name"].lower())


if __name__ == "__main__":
    print(json.dumps(get_apps()))
