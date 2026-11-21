#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import subprocess

from color_utils import (
    blend_hex, get_brightness, resolve_color, sanitize_color,
    contrast_ratio, ensure_contrast,
)
from theme_appliers import kcolorscheme

from theme_appliers import (
    btop,
    gtk,
    hyprland,
    hyprtoolkit,
    kitty,
    lazygit,
    nvim,
    qt,
    starship,
    svg_assets,
)
from xdg_paths import cache_home, config_home, data_home, state_home


def _run_applier(name, callback, *args, **kwargs):
    """Run one integration without preventing later integrations from running."""
    try:
        callback(*args, **kwargs)
        print(f"Veyra theme applier [{name}]: OK")
        return True
    except Exception as exc:
        print(f"Veyra theme applier [{name}] failed: {type(exc).__name__}: {exc}")
        return False


def main():
    home = os.environ.get("HOME", "")
    # Active palette lives in the state dir; fall back to the legacy cache copy.
    state_file = os.path.join(str(state_home(home)), "veyra", "colorscheme.json")
    legacy_file = os.path.join(str(cache_home(home)), "quickshell", "colorscheme.json")
    cache_file = state_file if os.path.exists(state_file) else legacy_file

    if not os.path.exists(cache_file):
        print("Colorscheme cache not found.")
        return

    try:
        with open(cache_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"Veyra theme: colorscheme cache is unreadable ({exc}); leaving integrations unchanged.")
        return
    if not isinstance(data, dict):
        print("Veyra theme: colorscheme cache is not a JSON object; leaving integrations unchanged.")
        return

    # Dynamic applier preferences are stored by SettingsService.qml.
    # Missing keys default to True to preserve existing behavior.
    prefs_file = os.path.join(str(state_home(home)), "veyra", "settings_prefs.json")
    if not os.path.exists(prefs_file):
        prefs_file = os.path.join(str(cache_home(home)), "quickshell", "settings_prefs.json")
    try:
        with open(prefs_file, "r", encoding="utf-8") as f:
            settings_prefs = json.load(f)
        if not isinstance(settings_prefs, dict):
            settings_prefs = {}
    except (OSError, ValueError):
        settings_prefs = {}

    def applier_enabled(key):
        return bool(settings_prefs.get(key, True))

    bg = sanitize_color(data.get("bg", "#000000"))
    opaqueBg = sanitize_color(data.get("opaqueBg", bg))
    fg = sanitize_color(data.get("fg", "#ffffff"))
    accent = sanitize_color(data.get("accent", "#a77ef5"))
    accentComplementary = sanitize_color(data.get("accentComplementary", "#f57eb6"))
    shadow = sanitize_color(data.get("shadow", "#000000"))

    requested_fg = fg
    requested_accent = accent
    requested_complementary = accentComplementary
    fg = ensure_contrast(fg, bg, 4.5)
    accent = ensure_contrast(accent, bg, 3.0)
    accentComplementary = ensure_contrast(accentComplementary, bg, 3.0)
    try:
        print(
            "Veyra contrast check: "
            f"text/background {contrast_ratio(fg, bg):.2f}:1 (target 4.5:1); "
            f"accent/background {contrast_ratio(accent, bg):.2f}:1 (target 3:1)."
        )
        if fg != requested_fg or accent != requested_accent or accentComplementary != requested_complementary:
            print("Veyra: adjusted low-contrast palette colors for readability.")
    except (TypeError, ValueError):
        print("Veyra: could not calculate contrast for one or more palette colors.")

    brightness = get_brightness(bg)
    is_dark = brightness <= 0.5

    # Derive overlayBase and all alpha/blended surfaces
    overlay_fallback = blend_hex(accent, fg, 0.7 if is_dark else 1.0)
    overlayBase = resolve_color(data.get("overlayBase"), bg, fallback=overlay_fallback)

    bgSecondary = resolve_color(
        data.get("bgSecondary"),
        bg,
        fallback=blend_hex(overlayBase, bg, 0.06 if is_dark else 0.10),
    )
    bgTertiary = resolve_color(
        data.get("bgTertiary"),
        bg,
        fallback=blend_hex(overlayBase, bg, 0.02 if is_dark else 0.04),
    )
    bgAccent = resolve_color(
        data.get("bgAccent"),
        bg,
        fallback=blend_hex(accent, bg, 0.15 if is_dark else 0.30),
    )
    bgAccentComplementary = resolve_color(
        data.get("bgAccentComplementary"),
        bg,
        fallback=blend_hex(accentComplementary, bg, 0.15 if is_dark else 0.30),
    )
    muted = resolve_color(data.get("muted"), bg, fallback=blend_hex(fg, bg, 0.40))
    border = resolve_color(
        data.get("border"),
        bg,
        fallback=blend_hex(fg, bg, 0.10 if is_dark else 0.20),
    )

    colors = {
        "bg": bg,
        "opaqueBg": opaqueBg,
        "fg": fg,
        "overlayBase": overlayBase,
        "bgSecondary": bgSecondary,
        "bgTertiary": bgTertiary,
        "bgAccent": bgAccent,
        "bgAccentComplementary": bgAccentComplementary,
        "muted": muted,
        "border": border,
        "accent": accent,
        "accentComplementary": accentComplementary,
        "shadow": shadow,
        "is_dark": is_dark,
    }

    # Add Matugen colors without replacing Veyra's original palette.
    try:
        from matugen_palette import generate as generate_matugen_palette
        colors.update(generate_matugen_palette(accent, is_dark))
    except Exception as e:
        print(f"Matugen palette generation failed; keeping Veyra colors: {e}")

    # Track the KDE and Qt palettes used by the system file chooser.
    from pathlib import Path
    chooser_palette_files = (
        data_home(home) / "color-schemes/Veyra.colors",
        config_home(home) / "qt6ct/colors/Veyra.conf",
    )
    chooser_palette_before = tuple(
        path.read_bytes() if path.is_file() else None
        for path in chooser_palette_files
    )

    if applier_enabled("dynamicThemeKColorSchemeEnabled"):
        _run_applier("KColorScheme", kcolorscheme.apply, home, colors)

    if applier_enabled("dynamicThemeKittyEnabled"):
        _run_applier("Kitty", kitty.apply, home, colors)
    if applier_enabled("dynamicThemeGtkEnabled"):
        _run_applier("GTK", gtk.apply, home, colors)
    if applier_enabled("dynamicThemeNeovimEnabled"):
        _run_applier("Neovim", nvim.apply, home, colors)
    if applier_enabled("dynamicThemeHyprlandEnabled"):
        _run_applier("Hyprland", hyprland.apply, home, colors)
        # hyprtoolkit consumes the same palette and has no user-facing toggle.
        _run_applier("Hyprtoolkit", hyprtoolkit.apply, home, colors)
    if applier_enabled("dynamicThemeStarshipEnabled"):
        _run_applier("Starship", starship.apply, home, colors)
    if applier_enabled("dynamicThemeQtEnabled"):
        _run_applier("Qt", qt.apply, home, colors, preserve_kcolorscheme=applier_enabled("dynamicThemeKColorSchemeEnabled"))
    if applier_enabled("dynamicThemeBtopEnabled"):
        _run_applier("Btop", btop.apply, home, colors)
    if applier_enabled("dynamicThemeSvgAssetsEnabled"):
        _run_applier("SVG assets", svg_assets.apply, home, colors)
    if applier_enabled("dynamicThemeLazygitEnabled"):
        _run_applier("LazyGit", lazygit.apply, home, colors)

    # Notify running toolkit applications as soon as the system palettes are written.
    # App-specific template output can take longer, so refresh global palettes first.
    # This remains best-effort; some apps ignore external theme notifications.
    refresh_args = [sys.executable, os.path.join(os.path.dirname(__file__), "refresh_live_themes.py")]
    if applier_enabled("dynamicThemeGtkEnabled"):
        refresh_args.append("--gtk")
    if applier_enabled("dynamicThemeQtEnabled"):
        refresh_args.append("--qt")
    if applier_enabled("dynamicThemeKColorSchemeEnabled"):
        refresh_args.append("--kde")
    if len(refresh_args) > 2:
        try:
            result = subprocess.run(refresh_args, capture_output=True, text=True, timeout=18, check=False)
            if result.stdout.strip():
                print(result.stdout.strip())
            if result.returncode != 0:
                detail = (result.stderr or result.stdout).strip()
                print(f"Veyra live theme refresh: helper returned {result.returncode}: {detail[:240]}")
        except (OSError, subprocess.SubprocessError) as exc:
            print(f"Veyra live theme refresh failed: {exc}")

    try:
        from app_theme_manager import apply as apply_app_theme_manager
        apply_app_theme_manager(home, colors)
    except Exception as e:
        print(f"Veyra app theme manager failed: {e}")

    # Apply user-imported custom templates after Veyra's built-in integrations.
    # The renderer never executes template shell hooks.
    try:
        from custom_template_manager import apply_enabled as apply_custom_templates
        apply_custom_templates(home, colors)
    except Exception as e:
        print(f"Veyra custom templates failed: {e}")

    # Refresh the KDE file chooser only when its generated palette changes.
    chooser_palette_after = tuple(
        path.read_bytes() if path.is_file() else None
        for path in chooser_palette_files
    )

    if chooser_palette_after != chooser_palette_before:
        try:
            result = subprocess.run(
                [
                    "systemctl", "--user", "try-restart",
                    "plasma-xdg-desktop-portal-kde.service",
                ],
                capture_output=True,
                text=True,
                timeout=12,
                check=False,
            )
            if result.returncode == 0:
                print("Veyra: KDE file-picker palette changed; portal refresh requested.")
            else:
                detail = (result.stderr or result.stdout).strip()
                print(f"Veyra: KDE file-picker refresh failed: {detail}")
        except (OSError, subprocess.SubprocessError) as exc:
            print(f"Veyra: could not refresh the KDE file picker: {exc}")

if __name__ == "__main__":
    main()
