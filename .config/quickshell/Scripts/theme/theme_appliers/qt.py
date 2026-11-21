
import configparser
import os
import io
import tempfile

from color_utils import sanitize_color
from xdg_paths import config_home


def atomic_write(path, content):
    """Replace a config file atomically so qt5ct/qt6ct directory watchers see it."""
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, temporary_path = tempfile.mkstemp(
        prefix=f".{os.path.basename(path)}.", suffix=".tmp", dir=directory
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            file.write(content)
            file.flush()
            os.fsync(file.fileno())
        # Renaming inside the watched config directory emits a directory-change
        # event; qt6ct/qt5ct can then reload the palette into running widgets.
        os.replace(temporary_path, path)
    except BaseException:
        try:
            os.unlink(temporary_path)
        except OSError:
            pass
        raise


def apply(home, colors, preserve_kcolorscheme=False):
    is_dark = colors["is_dark"]

    def qt_color(value):
        s = sanitize_color(value)
        if s.startswith("#") and len(s) == 7:
            return "#ff" + s[1:]
        return s

    bg = qt_color(colors.get("m3_surface_container_lowest", colors["bg"]))
    fg = qt_color(colors.get("m3_on_surface", colors["fg"]))
    accent = qt_color(colors.get("m3_primary", colors["accent"]))
    complementary = qt_color(colors.get("m3_tertiary", colors["accentComplementary"]))
    muted = qt_color(colors.get("m3_on_surface_variant", colors["muted"]))
    shadow = qt_color(colors["shadow"])
    surface = qt_color(colors.get("m3_surface_container", colors.get("bgSecondary", colors["bg"])))
    surface_variant = qt_color(colors.get("m3_surface_container_high", colors.get("bgTertiary", colors.get("bgSecondary", colors["bg"]))))
    selection = qt_color(colors.get("m3_primary", colors.get("bgAccent", colors["accent"])))
    on_selection = qt_color(colors.get("m3_on_primary", colors["bg"]))
    outline = qt_color(colors.get("m3_outline", colors.get("border", colors["muted"])))

    active = [
        fg, surface, surface_variant, outline, bg, outline,
        fg, "#ffffffff", fg, bg, bg, shadow, selection, on_selection,
        accent, complementary, surface_variant, fg, surface_variant,
        fg, muted,
    ]

    inactive = active.copy()
    inactive[0] = muted
    inactive[6] = muted
    inactive[8] = muted
    inactive[19] = muted

    disabled = active.copy()
    disabled[0] = muted
    disabled[6] = muted
    disabled[8] = muted
    disabled[13] = surface
    disabled[14] = muted
    disabled[15] = muted
    disabled[19] = muted
    disabled[20] = muted

    def palette_line(values):
        return ", ".join(values)

    content = (
        "[ColorScheme]\n"
        f"active_colors={palette_line(active)}\n"
        f"inactive_colors={palette_line(inactive)}\n"
        f"disabled_colors={palette_line(disabled)}\n"
    )

    # Preserve KDE scheme selection when KColorScheme is enabled.
    qt_targets = ("qt5ct",) if preserve_kcolorscheme else ("qt5ct", "qt6ct")
    for qtct in qt_targets:
        directory = os.path.join(str(config_home(home)), qtct, "colors")
        os.makedirs(directory, exist_ok=True)
        scheme_path = os.path.join(directory, "Veyra.conf")

        atomic_write(scheme_path, content)

        config_path = os.path.join(str(config_home(home)), qtct, f"{qtct}.conf")
        config = configparser.ConfigParser()
        config.optionxform = str
        if os.path.exists(config_path):
            config.read(config_path)

        if "Appearance" not in config:
            config["Appearance"] = {}

        # Materialize a usable config even on systems where only the palette
        # folder existed. Running apps only consume this if their platform-theme
        # plugin (qt5ct/qt6ct) was loaded when that app started.
        config["Appearance"]["color_scheme_path"] = scheme_path
        config["Appearance"]["custom_palette"] = "true"
        config["Appearance"]["icon_theme"] = (
            "Papirus-Dark" if is_dark else "Papirus-Light"
        )
        config["Appearance"].setdefault("style", "Fusion")

        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        buffer = io.StringIO()
        config.write(buffer)
        atomic_write(config_path, buffer.getvalue())

