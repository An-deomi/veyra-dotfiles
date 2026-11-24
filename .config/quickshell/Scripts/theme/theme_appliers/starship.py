from __future__ import annotations

import re
from pathlib import Path

from xdg_paths import config_home
from color_utils import sanitize_color
from theme_appliers.file_utils import atomic_write_text


_TABLE_HEADER = re.compile(r"^\s*\[+[^\]]+\]+\s*(?:#.*)?(?:\r?\n)?$")
_TARGET_TABLE = re.compile(r"^\s*\[palettes\.quickshell\]\s*(?:#.*)?(?:\r?\n)?$")
_MARKER = "# --- Quickshell Palette ---"


def _set_table_values(text: str, values: dict[str, str]) -> str:
    lines = text.splitlines(keepends=True)
    table_indexes = [i for i, line in enumerate(lines) if _TARGET_TABLE.match(line)]

    if len(table_indexes) > 1:
        raise ValueError("multiple [palettes.quickshell] tables found; refusing an ambiguous edit")

    if table_indexes:
        table_start = table_indexes[0]
        table_end = len(lines)
        for i in range(table_start + 1, len(lines)):
            if _TABLE_HEADER.match(lines[i]):
                table_end = i
                break

        # Ensure the generated block is labelled, without moving or deleting
        # any user-authored lines around the table.
        if not any(line.strip() == _MARKER for line in lines[:table_start]):
            lines.insert(table_start, _MARKER + "\n")
            table_start += 1
            table_end += 1
    else:
        if lines and not lines[-1].endswith(("\n", "\r")):
            lines[-1] += "\n"
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.extend([_MARKER + "\n", "[palettes.quickshell]\n"])
        table_start = len(lines) - 1
        table_end = len(lines)

    for key, value in values.items():
        key_re = re.compile(rf"^([ \t]*){re.escape(key)}([ \t]*=[ \t]*)(.*?)(\r?\n)?$")
        matches = [i for i in range(table_start + 1, table_end) if key_re.match(lines[i])]
        if len(matches) > 1:
            raise ValueError(f"duplicate '{key}' entry in [palettes.quickshell]; refusing an ambiguous edit")

        if matches:
            index = matches[0]
            match = key_re.match(lines[index])
            assert match is not None
            # Keep inline comments and original indentation, but replace only
            # the value owned by Veyra.
            trailing = match.group(3)
            comment_match = re.search(r"\s+#.*$", trailing)
            comment = comment_match.group(0) if comment_match else ""
            newline = match.group(4) or ""
            lines[index] = f'{match.group(1)}{key}{match.group(2)}"{value}"{comment}{newline}'
        else:
            insertion = f'{key} = "{value}"\n'
            lines.insert(table_end, insertion)
            table_end += 1

    return "".join(lines)


def apply(home, colors):
    values = {
        "bg": sanitize_color(colors["bg"]),
        "fg": sanitize_color(colors["fg"]),
        "accent": sanitize_color(colors["accent"]),
        "accentcomplementary": sanitize_color(colors["accentComplementary"]),
    }

    starship_file = config_home(home) / "starship" / "starship.toml"
    starship_file.parent.mkdir(parents=True, exist_ok=True)
    try:
        original = starship_file.read_text(encoding="utf-8")
    except FileNotFoundError:
        original = ""

    updated = _set_table_values(original, values)
    if updated != original:
        atomic_write_text(starship_file, updated)

    # Ensure ~/.config/starship.toml points to starship/starship.toml when absent
    # so Starship loads Veyra's palette without requiring STARSHIP_CONFIG.
    root_toml = config_home(home) / "starship.toml"
    if not root_toml.exists() and not root_toml.is_symlink():
        try:
            root_toml.symlink_to("starship/starship.toml")
        except OSError:
            pass
