#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import subprocess

OPTIONS = [
    "decoration:blur:enabled",
    "decoration:rounding",
    "decoration:active_opacity",
    "decoration:inactive_opacity",
    "decoration:blur:size",
    "decoration:blur:passes",
    "general:gaps_in",
    "general:gaps_out",
    "general:layout",
    "dwindle:preserve_split",
    "dwindle:smart_split",
    "dwindle:smart_resizing",
    "dwindle:force_split",
    "dwindle:default_split_ratio",
    "dwindle:permanent_direction_override",
    "dwindle:split_width_multiplier",
    "dwindle:use_active_for_splits",
    "dwindle:split_bias",
    "dwindle:precise_mouse_move",
    "master:mfact",
    "master:orientation",
    "master:new_status",
    "master:allow_small_split",
    "master:smart_resizing",
    "master:new_on_top",
    "master:new_on_active",
    "master:drop_at_cursor",
    "master:always_keep_position",
    "master:focus_master_on_close",
    "master:slave_count_for_center_master",
    "master:center_master_fallback",
    "general:border_size",
    "decoration:shadow:enabled",
    "decoration:shadow:range",
    "decoration:shadow:render_power",
    "animations:enabled",
    "input:sensitivity",
    "input:accel_profile",
    "input:natural_scroll",
    "input:scroll_factor",
    "input:left_handed",
    "input:follow_mouse",
    "cursor:inactive_timeout",
    "cursor:no_warps",
    "input:touchpad:natural_scroll",
    "input:touchpad:tap-to-click",
    "input:touchpad:disable_while_typing",
]


def main():
    res = {}
    for opt in OPTIONS:
        try:
            out = subprocess.check_output(
                ["hyprctl", "getoption", opt, "-j"],
                stderr=subprocess.DEVNULL,
            ).decode("utf-8")
            data = json.loads(out)
            if "int" in data:
                res[opt] = data["int"]
            elif "float" in data:
                res[opt] = data["float"]
            elif "bool" in data:
                res[opt] = data["bool"]
            elif "str" in data:
                res[opt] = data["str"]
            elif "custom" in data:
                res[opt] = data["custom"]
            elif "css" in data:
                parts = str(data["css"]).split()
                if parts:
                    res[opt] = int(parts[0])
        except Exception:
            continue

    print(json.dumps(res))


if __name__ == "__main__":
    main()
