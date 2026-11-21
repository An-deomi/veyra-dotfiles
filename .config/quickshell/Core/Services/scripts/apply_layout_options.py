#!/usr/bin/env python3
"""Apply advanced Hyprland layout options without reloading the session."""

import json
import subprocess
import sys

ALLOWED = {
    "dwindle": {
        "preserve_split",
        "smart_split",
        "smart_resizing",
        "force_split",
        "default_split_ratio",
        "permanent_direction_override",
        "split_width_multiplier",
        "use_active_for_splits",
        "split_bias",
        "precise_mouse_move",
    },
    "master": {
        "mfact",
        "orientation",
        "new_status",
        "allow_small_split",
        "smart_resizing",
        "new_on_top",
        "new_on_active",
        "drop_at_cursor",
        "always_keep_position",
        "focus_master_on_close",
        "slave_count_for_center_master",
        "center_master_fallback",
    },
}


def value_text(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return str(value)


def validate(section, key, value):
    enum_values = {
        ("master", "orientation"): {"left", "right", "top", "bottom", "center"},
        ("master", "new_status"): {"master", "slave", "inherit"},
        ("master", "new_on_active"): {"none", "before", "after"},
        ("master", "center_master_fallback"): {"left", "right", "top", "bottom"},
    }
    boolean_keys = {
        ("dwindle", key) for key in (
            "preserve_split", "smart_split", "smart_resizing",
            "permanent_direction_override", "use_active_for_splits", "precise_mouse_move"
        )
    } | {
        ("master", key) for key in (
            "allow_small_split", "smart_resizing", "new_on_top", "drop_at_cursor",
            "always_keep_position", "focus_master_on_close"
        )
    }
    if (section, key) in enum_values:
        if value not in enum_values[(section, key)]:
            raise ValueError(f"Invalid value for {section}:{key}.")
    if (section, key) in boolean_keys and not isinstance(value, bool):
        raise ValueError(f"{section}:{key} must be true or false.")
    if (section, key) == ("dwindle", "force_split") and value not in (0, 1, 2):
        raise ValueError("dwindle:force_split must be 0, 1 or 2.")
    if (section, key) == ("dwindle", "split_bias") and value not in (0, 1):
        raise ValueError("dwindle:split_bias must be 0 or 1.")
    if (section, key) == ("dwindle", "default_split_ratio") and not 0.1 <= float(value) <= 1.9:
        raise ValueError("dwindle:default_split_ratio must be between 0.1 and 1.9.")
    if (section, key) == ("dwindle", "split_width_multiplier") and not 0.1 <= float(value) <= 3.0:
        raise ValueError("dwindle:split_width_multiplier must be between 0.1 and 3.0.")
    if (section, key) == ("master", "mfact") and not 0.0 <= float(value) <= 1.0:
        raise ValueError("master:mfact must be between 0 and 1.")
    if (section, key) == ("master", "slave_count_for_center_master") and not 0 <= int(value) <= 10:
        raise ValueError("master:slave_count_for_center_master must be between 0 and 10.")


def main():
    if len(sys.argv) != 2:
        raise ValueError("Expected a JSON object of Hyprland layout options.")
    payload = json.loads(sys.argv[1])
    if not isinstance(payload, dict):
        raise ValueError("Layout options must be an object.")

    failures = []
    for section, allowed_keys in ALLOWED.items():
        values = payload.get(section, {})
        if not isinstance(values, dict):
            continue
        for key, value in values.items():
            if key not in allowed_keys:
                continue
            validate(section, key, value)
            option_name = f"{section}:{key}"
            # Skip options that are not supported by the installed Hyprland build.
            probe = subprocess.run(
                ["hyprctl", "getoption", option_name, "-j"],
                check=False,
                capture_output=True,
                text=True,
            )
            if probe.returncode != 0:
                continue
            try:
                json.loads(probe.stdout)
            except json.JSONDecodeError:
                continue

            result = subprocess.run(
                ["hyprctl", "keyword", option_name, value_text(value)],
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                message = (result.stderr or result.stdout or "unknown error").strip()
                failures.append(f"{section}:{key}: {message}")

    if failures:
        print("\n".join(failures), file=sys.stderr)
        sys.exit(1)
    print("Layout options applied")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
