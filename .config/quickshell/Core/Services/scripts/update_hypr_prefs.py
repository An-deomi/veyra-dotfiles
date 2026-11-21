#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import re
import tempfile


def update_lua(content, updates):
    lines = content.split("\n")
    scope = []

    flat_updates = {}

    def flatten(d, prefix=""):
        for k, v in d.items():
            if isinstance(v, dict):
                flatten(v, prefix + k + ".")
            else:
                flat_updates[prefix + k] = v

    flatten(updates)

    out_lines = []
    i = 0
    seen_keys = set()
    seen_top_level = set()

    def format_lua_val(v):
        if isinstance(v, bool):
            return str(v).lower()
        if isinstance(v, (int, float)):
            return str(v)
        if isinstance(v, str):
            if (v.startswith('"') and v.endswith('"')) or (
                v.startswith("'") and v.endswith("'")
            ):
                return v
            return f'"{v}"'
        return str(v)

    while i < len(lines):
        line = lines[i]

        m_config_end = re.search(r"^\s*\}\)", line)
        if m_config_end and len(scope) == 0:
            for top_k, top_v in updates.items():
                if top_k not in seen_top_level:
                    out_lines.append(f"        {top_k} = {{")

                    def write_block(d, indent_lvl):
                        for k, v in d.items():
                            indent = " " * (indent_lvl * 8)
                            if isinstance(v, dict):
                                out_lines.append(f"{indent}{k} = {{")
                                write_block(v, indent_lvl + 1)
                                out_lines.append(f"{indent}}},")
                            else:
                                v_str = format_lua_val(v)
                                out_lines.append(f"{indent}{k} = {v_str},")

                    write_block(top_v, 2)
                    out_lines.append("        },")
            out_lines.append(line)
            i += 1
            continue

        m_start = re.search(r"^\s*([a-zA-Z0-9_]+)\s*=\s*\{", line)
        if m_start:
            scope_name = m_start.group(1)
            scope.append(scope_name)
            if len(scope) == 1:
                seen_top_level.add(scope_name)
            out_lines.append(line)
            i += 1
            continue

        m_end = re.search(r"^\s*\},?", line)
        if m_end and len(scope) > 0:
            current_prefix = ".".join(scope) + "."

            missing_in_scope = {}
            for k, v in flat_updates.items():
                if k.startswith(current_prefix) and k not in seen_keys:
                    sub_path = k[len(current_prefix) :].split(".")
                    curr = missing_in_scope
                    for p in sub_path[:-1]:
                        if p not in curr:
                            curr[p] = {}
                        curr = curr[p]
                    curr[sub_path[-1]] = v
                    seen_keys.add(k)

            if missing_in_scope:

                def write_missing(d, indent_lvl):
                    indent_str = " " * (indent_lvl * 8 - 8)
                    for mk, mv in d.items():
                        if isinstance(mv, dict):
                            out_lines.append(f"{indent_str}{mk} = {{")
                            write_missing(mv, indent_lvl + 1)
                            out_lines.append(f"{indent_str}}},")
                        else:
                            v_str = format_lua_val(mv)
                            out_lines.append(f"{indent_str}{mk} = {v_str},")

                write_missing(missing_in_scope, len(scope) + 2)

            scope.pop()
            out_lines.append(line)
            i += 1
            continue

        m_kv = re.search(r"^(\s*)([a-zA-Z0-9_]+)(\s*=\s*)([^,]+)(,?)", line)
        if m_kv and len(scope) > 0:
            key = m_kv.group(2)
            full_key = ".".join(scope) + "." + key
            if full_key in flat_updates:
                val = flat_updates[full_key]
                v_str = format_lua_val(val)
                out_lines.append(
                    f"{m_kv.group(1)}{key}{m_kv.group(3)}{v_str}{m_kv.group(5)}"
                )
                seen_keys.add(full_key)
                i += 1
                continue

        out_lines.append(line)
        i += 1

    return "\n".join(out_lines)


def validate_updates(value, path="preferences"):
    if not isinstance(value, dict) or not value:
        raise ValueError(f"{path} must be a non-empty object")

    for key, item in value.items():
        if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError(f"Invalid preference key: {key!r}")

        if isinstance(item, dict):
            validate_updates(item, f"{path}.{key}")
        elif isinstance(item, str):
            if "\n" in item or "\r" in item:
                raise ValueError(f"Newlines are not allowed in {path}.{key}")
            if '"' in item or "\\" in item:
                raise ValueError(f"Quotes and backslashes are not allowed in {path}.{key}")
        elif isinstance(item, bool) or isinstance(item, int):
            continue
        elif isinstance(item, float):
            import math
            if not math.isfinite(item):
                raise ValueError(f"Invalid number in {path}.{key}")
        else:
            raise ValueError(f"Unsupported value in {path}.{key}")


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Expected one JSON preferences argument")

        try:
            updates = json.loads(sys.argv[1])
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON: {exc}") from exc

        validate_updates(updates)

        config_home = os.environ.get(
            "XDG_CONFIG_HOME",
            os.path.expanduser("~/.config"),
        )
        prefs_path = os.path.join(config_home, "hypr", "userprefs.lua")

        if not os.path.isfile(prefs_path):
            raise FileNotFoundError(f"Hyprland preferences file not found: {prefs_path}")

        with open(prefs_path, "r", encoding="utf-8") as handle:
            content = handle.read()

        new_content = update_lua(content, updates)

        if not isinstance(new_content, str) or not new_content.strip():
            raise ValueError("Updater produced invalid or empty content")

        file_mode = os.stat(prefs_path).st_mode & 0o777

        fd, temp_name = tempfile.mkstemp(
            prefix=".userprefs.",
            dir=os.path.dirname(prefs_path),
            text=True,
        )

        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(new_content)
                handle.flush()
                os.fsync(handle.fileno())

            os.chmod(temp_name, file_mode)
            os.replace(temp_name, prefs_path)

        finally:
            if os.path.exists(temp_name):
                os.unlink(temp_name)

        print(f"Updated {prefs_path}")

    except Exception as exc:
        print(f"Hyprland preferences update failed: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
