"""Keep hyprtoolkit.conf (chrome for hypr* apps) on the active palette.

The file used to be a hand-written static config with a gold accent, so every
theme change left it visibly behind. hyprtoolkit takes colours as
rgba(RRGGBBAA) without the leading '#'.
"""

import os

from color_utils import blend_hex
from theme_appliers.file_utils import atomic_write_text
from xdg_paths import config_home


def _flatten(value, bg):
    """Palette entries are Qt #AARRGGBB; blend translucent ones onto the base."""
    hex_value = str(value).strip().lstrip("#")
    if len(hex_value) == 8:
        alpha = int(hex_value[0:2], 16) / 255.0
        return blend_hex(hex_value[2:], bg, alpha)
    return value


def _rgba(value, alpha="ff"):
    hex_value = str(value).strip().lstrip("#")
    if len(hex_value) == 8:
        hex_value = hex_value[:6]
    if len(hex_value) != 6:
        raise ValueError(f"unexpected colour value: {value!r}")
    return f"rgba({hex_value.lower()}{alpha})"


def apply(home, colors):
    bg = _flatten(colors["bg"], "#000000")
    fg = colors["fg"]
    secondary = _flatten(colors.get("bgSecondary", bg), bg)
    accent = colors["accent"]
    accent_secondary = colors.get("accentComplementary", accent)

    content = "\n".join(
        [
            f"background = {_rgba(bg)}",
            f"base = {_rgba(bg)}",
            f"text = {_rgba(fg)}",
            f"alternate_base = {_rgba(secondary)}",
            f"bright_text = {_rgba(fg)}",
            f"accent = {_rgba(accent)}",
            f"accent_secondary = {_rgba(accent_secondary)}",
        ]
    ) + "\n"

    hypr_dir = os.path.join(str(config_home(home)), "hypr")
    os.makedirs(hypr_dir, exist_ok=True)
    atomic_write_text(os.path.join(hypr_dir, "hyprtoolkit.conf"), content)
