from __future__ import annotations

import re

from xdg_paths import config_home
from color_utils import sanitize_color
from theme_appliers.file_utils import atomic_write_text


_MARKER = "# --- Quickshell Palette ---"
_GUI_HEADER = re.compile(r"^gui\s*:\s*(?:#.*)?(?:\r?\n)?$")
_GUI_KEY = re.compile(r"^gui\s*:")
_THEME_HEADER = re.compile(r"^  theme\s*:\s*(?:#.*)?(?:\r?\n)?$")


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _is_content(line: str) -> bool:
    stripped = line.strip()
    return bool(stripped) and not stripped.startswith("#")


def _mapping_end(lines: list[str], start: int, parent_indent: int) -> int:
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if not _is_content(line):
            continue
        if line.startswith("---") or line.startswith("..."):
            return index
        if _indent(line) <= parent_indent:
            return index
    return len(lines)


def _find_key(lines: list[str], start: int, end: int, indent: int, key: str) -> list[int]:
    pattern = re.compile(rf"^ {{{indent}}}{re.escape(key)}\s*:")
    return [i for i in range(start, end) if pattern.match(lines[i])]


def _quote_yaml(value: str) -> str:
    # All Veyra colors are sanitized hex values, but keep this helper safe for
    # any future string passed through it.
    return "'" + value.replace("'", "''") + "'"


def _set_scalar(lines: list[str], start: int, end: int, indent: int, key: str, value: str) -> None:
    matches = _find_key(lines, start, end, indent, key)
    if len(matches) > 1:
        raise ValueError(f"duplicate LazyGit gui.{key} entries; refusing an ambiguous edit")
    if matches:
        index = matches[0]
        match = re.match(rf"^( {{{indent}}}{re.escape(key)}\s*:\s*)(.*?)(\s+#.*)?(\r?\n)?$", lines[index])
        if not match:
            raise ValueError(f"unsupported YAML syntax for gui.{key}")
        comment = match.group(3) or ""
        newline = match.group(4) or ""
        lines[index] = f"{match.group(1)}{_quote_yaml(value)}{comment}{newline}"
    else:
        lines.insert(end, f"{' ' * indent}{key}: {_quote_yaml(value)}\n")


def _set_list_first_value(lines: list[str], start: int, end: int, key: str, value: str) -> None:
    matches = _find_key(lines, start, end, 4, key)
    if len(matches) > 1:
        raise ValueError(f"duplicate LazyGit gui.theme.{key} entries; refusing an ambiguous edit")

    if not matches:
        lines.insert(end, f"    {key}:\n")
        lines.insert(end + 1, f"      - {_quote_yaml(value)}\n")
        return

    key_index = matches[0]
    header_match = re.match(rf"^(    {re.escape(key)}\s*:\s*)(.*?)(\s+#.*)?(\r?\n)?$", lines[key_index])
    if not header_match:
        raise ValueError(f"unsupported YAML syntax for gui.theme.{key}")

    # If the value is inline (for example, a flow list), replace it with the
    # block-list form used by LazyGit's existing Veyra palette.
    inline_value = header_match.group(2).strip()
    if inline_value:
        comment = header_match.group(3) or ""
        newline = header_match.group(4) or "\n"
        lines[key_index] = f"    {key}:{comment}{newline}"
        lines.insert(key_index + 1, f"      - {_quote_yaml(value)}\n")
        return

    child_end = _mapping_end(lines, key_index, 4)
    item_indexes = [
        i for i in range(key_index + 1, child_end)
        if re.match(r"^      -\s*", lines[i])
    ]
    if item_indexes:
        item_index = item_indexes[0]
        item_match = re.match(r"^(      -\s*)(.*?)(\s+#.*)?(\r?\n)?$", lines[item_index])
        if not item_match:
            raise ValueError(f"unsupported YAML list syntax for gui.theme.{key}")
        comment = item_match.group(3) or ""
        newline = item_match.group(4) or "\n"
        lines[item_index] = f"{item_match.group(1)}{_quote_yaml(value)}{comment}{newline}"
    else:
        unexpected_children = [
            lines[i] for i in range(key_index + 1, child_end) if _is_content(lines[i])
        ]
        if unexpected_children:
            raise ValueError(f"unsupported nested YAML value for gui.theme.{key}; refusing to alter it")
        lines.insert(key_index + 1, f"      - {_quote_yaml(value)}\n")


def _update_lazygit_yaml(text: str, scalar_values: dict[str, str], list_values: dict[str, str]) -> str:
    lines = text.splitlines(keepends=True)
    gui_indexes = [i for i, line in enumerate(lines) if _GUI_HEADER.match(line)]
    unsupported_gui = [i for i, line in enumerate(lines) if _GUI_KEY.match(line) and not _GUI_HEADER.match(line)]
    if unsupported_gui and not gui_indexes:
        raise ValueError("gui uses inline or anchored YAML syntax; refusing to append a duplicate gui mapping")

    if gui_indexes:
        # The old applier appended its generated gui mapping at EOF. Updating
        # the last gui mapping keeps that existing behavior while preserving
        # every line before and after it.
        gui_start = gui_indexes[-1]
        gui_end = _mapping_end(lines, gui_start, 0)
    else:
        if lines and not lines[-1].endswith(("\n", "\r")):
            lines[-1] += "\n"
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.extend([_MARKER + "\n", "gui:\n"])
        gui_start = len(lines) - 1
        gui_end = len(lines)

    theme_indexes = [i for i in range(gui_start + 1, gui_end) if _THEME_HEADER.match(lines[i])]
    if len(theme_indexes) > 1:
        raise ValueError("multiple gui.theme mappings found; refusing an ambiguous edit")

    # Update scalar GUI options without replacing the user's gui mapping.
    for key, value in scalar_values.items():
        gui_end = _mapping_end(lines, gui_start, 0)
        matches = _find_key(lines, gui_start + 1, gui_end, 2, key)
        if len(matches) > 1:
            raise ValueError(f"duplicate LazyGit gui.{key} entries; refusing an ambiguous edit")
        if matches:
            _set_scalar(lines, gui_start + 1, gui_end, 2, key, value)
        else:
            lines.insert(gui_end, f"  {key}: {_quote_yaml(value)}\n")

    gui_end = _mapping_end(lines, gui_start, 0)
    theme_indexes = [i for i in range(gui_start + 1, gui_end) if _THEME_HEADER.match(lines[i])]
    if theme_indexes:
        theme_start = theme_indexes[0]
        theme_end = _mapping_end(lines, theme_start, 2)
    else:
        if gui_end > gui_start + 1 and not lines[gui_end - 1].endswith(("\n", "\r")):
            lines[gui_end - 1] += "\n"
        lines.insert(gui_end, "  theme:\n")
        theme_start = gui_end
        theme_end = theme_start + 1

    for key, value in list_values.items():
        theme_end = _mapping_end(lines, theme_start, 2)
        _set_list_first_value(lines, theme_start + 1, theme_end, key, value)

    # Add the marker only when creating a new gui mapping. If a marker already
    # exists elsewhere in a user's file, leave it exactly where it is.
    if not any(line.strip() == _MARKER for line in lines):
        lines.insert(theme_start, "  " + _MARKER + "\n")

    return "".join(lines)


def apply(home, colors):
    scalar_values = {
        "border": "rounded",
        "nerdFontsVersion": "3",
    }
    list_values = {
        "activeBorderColor": sanitize_color(colors["accent"]),
        "inactiveBorderColor": sanitize_color(colors["border"]),
        "optionsTextColor": sanitize_color(colors["accentComplementary"]),
        "selectedLineBgColor": sanitize_color(colors.get("bgAccent", colors["bgSecondary"])),
        "cherryPickedCommitBgColor": sanitize_color(colors.get("bgAccentComplementary", colors["accentComplementary"])),
        "cherryPickedCommitFgColor": sanitize_color(colors["bg"]),
        "unstagedChangesColor": sanitize_color(colors["accentComplementary"]),
        "defaultFgColor": sanitize_color(colors["fg"]),
    }

    lazygit_file = config_home(home) / "lazygit" / "config.yml"
    lazygit_file.parent.mkdir(parents=True, exist_ok=True)
    try:
        original = lazygit_file.read_text(encoding="utf-8")
    except FileNotFoundError:
        original = ""

    updated = _update_lazygit_yaml(original, scalar_values, list_values)
    if updated != original:
        atomic_write_text(lazygit_file, updated)
