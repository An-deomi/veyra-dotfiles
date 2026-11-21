import os

from xdg_paths import config_home, data_home
import re
import subprocess

from color_utils import sanitize_color


def apply(home, colors):
    bg = colors["bg"]
    fg = colors["fg"]
    bgSecondary = colors["bgSecondary"]
    bgTertiary = colors.get("bgTertiary", bgSecondary)
    bgAccent = colors.get("bgAccent", colors["accent"])
    bgAccentComplementary = colors.get(
        "bgAccentComplementary", colors["accentComplementary"]
    )
    overlayBase = colors.get("overlayBase", colors["accent"])
    accent = colors["accent"]
    accentComplementary = colors["accentComplementary"]
    muted = colors["muted"]
    border = colors["border"]
    shadow = colors["shadow"]
    is_dark = colors["is_dark"]

    mapping = {
        "primary": accent,
        "on_primary": bg,
        "primary_container": bgAccent,
        "on_primary_container": accent,
        "inverse_primary": bg,
        "primary_fixed": accent,
        "primary_fixed_dim": accent,
        "on_primary_fixed": bg,
        "on_primary_fixed_variant": accent,
        "secondary": fg,
        "on_secondary": bg,
        "secondary_container": bgSecondary,
        "on_secondary_container": fg,
        "secondary_fixed": fg,
        "secondary_fixed_dim": fg,
        "on_secondary_fixed": bg,
        "on_secondary_fixed_variant": fg,
        "tertiary": accentComplementary,
        "on_tertiary": bg,
        "tertiary_container": bgAccentComplementary,
        "on_tertiary_container": accentComplementary,
        "tertiary_fixed": accentComplementary,
        "tertiary_fixed_dim": accentComplementary,
        "on_tertiary_fixed": bg,
        "on_tertiary_fixed_variant": accentComplementary,
        "error": fg,
        "on_error": "#ffffff",
        "error_container": bgSecondary,
        "on_error_container": fg,
        "background": bg,
        "on_background": fg,
        "surface": bg,
        "on_surface": fg,
        "surface_dim": bg,
        "surface_bright": bgSecondary,
        "surface_container_lowest": bg,
        "surface_container_low": bgTertiary,
        "surface_container": bgSecondary,
        "surface_container_high": bgSecondary,
        "surface_container_highest": bgAccent,
        "surface_variant": bgSecondary,
        "on_surface_variant": muted,
        "surface_tint": bg,
        "outline": border,
        "outline_variant": border,
        "inverse_surface": fg,
        "inverse_on_surface": bg,
        "shadow": shadow,
        "scrim": shadow,
        "source_color": accent,
        "accent": accent,
        "accent_complementary": accentComplementary,
        "bg_secondary": bgSecondary,
        "bg_tertiary": bgTertiary,
        "bg_accent": bgAccent,
        "bg_accent_complementary": bgAccentComplementary,
        "overlay_base": overlayBase,
        "muted": muted,
    }

    mapping.update({
        "primary": colors.get("m3_primary", accent),
        "on_primary": colors.get("m3_on_primary", bg),
        "primary_container": colors.get("m3_primary_container", bgAccent),
        "on_primary_container": colors.get("m3_on_primary_container", fg),
        "secondary": colors.get("m3_secondary", fg),
        "on_secondary": colors.get("m3_on_secondary", bg),
        "secondary_container": colors.get("m3_secondary_container", bgSecondary),
        "on_secondary_container": colors.get("m3_on_secondary_container", fg),
        "tertiary": colors.get("m3_tertiary", accentComplementary),
        "on_tertiary": colors.get("m3_on_tertiary", bg),
        "tertiary_container": colors.get("m3_tertiary_container", bgAccentComplementary),
        "on_tertiary_container": colors.get("m3_on_tertiary_container", fg),
        "error": colors.get("m3_error", fg),
        "on_error": colors.get("m3_on_error", "#ffffff"),
        "error_container": colors.get("m3_error_container", bgSecondary),
        "on_error_container": colors.get("m3_on_error_container", fg),
        "background": colors.get("m3_background", bg),
        "on_background": colors.get("m3_on_background", fg),
        "surface": colors.get("m3_surface", bg),
        "on_surface": colors.get("m3_on_surface", fg),
        "surface_dim": colors.get("m3_surface_dim", bg),
        "surface_bright": colors.get("m3_surface_bright", bgSecondary),
        "surface_container_lowest": colors.get("m3_surface_container_lowest", bg),
        "surface_container_low": colors.get("m3_surface_container_low", bgTertiary),
        "surface_container": colors.get("m3_surface_container", bgSecondary),
        "surface_container_high": colors.get("m3_surface_container_high", bgSecondary),
        "surface_container_highest": colors.get("m3_surface_container_highest", bgAccent),
        "surface_variant": colors.get("m3_surface_variant", bgSecondary),
        "on_surface_variant": colors.get("m3_on_surface_variant", muted),
        "outline": colors.get("m3_outline", border),
        "outline_variant": colors.get("m3_outline_variant", border),
        "inverse_surface": colors.get("m3_inverse_surface", fg),
        "inverse_on_surface": colors.get("m3_inverse_on_surface", bg),
        "surface_tint": colors.get("m3_primary", accent),
        "source_color": colors.get("m3_primary", accent),
        "accent": colors.get("m3_primary", accent),
    })

    # Noctalia-style GTK theming: Adwaita base + generated palette CSS.
    gtk_roles = {
        "accent_color": mapping["primary"],
        "accent_bg_color": mapping["primary"],
        "accent_fg_color": mapping["on_primary"],
        "destructive_bg_color": mapping["error"],
        "destructive_fg_color": mapping["on_error"],
        "error_bg_color": mapping["error"],
        "error_fg_color": mapping["on_error"],
        "window_bg_color": mapping["surface"],
        "window_fg_color": mapping["on_surface"],
        "view_bg_color": mapping["surface"],
        "view_fg_color": mapping["on_surface"],
        "headerbar_bg_color": mapping["surface_container"],
        "headerbar_fg_color": mapping["on_surface"],
        "headerbar_backdrop_color": mapping["surface"],
        "popover_bg_color": mapping["surface_container"],
        "popover_fg_color": mapping["on_surface"],
        "card_bg_color": mapping["surface_container"],
        "card_fg_color": mapping["on_surface"],
        "dialog_bg_color": mapping["surface"],
        "dialog_fg_color": mapping["on_surface"],
        "overview_bg_color": mapping["surface_container"],
        "overview_fg_color": mapping["on_surface"],
        "sidebar_bg_color": mapping["surface_container"],
        "sidebar_fg_color": mapping["on_surface"],
        "sidebar_backdrop_color": mapping["surface"],
        "sidebar_border_color": mapping["surface"],
        "secondary_sidebar_bg_color": mapping["surface"],
        "secondary_sidebar_fg_color": mapping["on_surface"],
    }

    legacy_roles = {
        "theme_selected_bg_color": gtk_roles["accent_bg_color"],
        "theme_selected_fg_color": gtk_roles["accent_fg_color"],
        "theme_unfocused_fg_color": mapping["on_surface"],
        "theme_unfocused_text_color": mapping["on_surface"],
        "theme_unfocused_bg_color": mapping["surface"],
        "theme_unfocused_base_color": mapping["surface"],
        "theme_unfocused_selected_bg_color": gtk_roles["accent_bg_color"],
        "theme_unfocused_selected_fg_color": gtk_roles["accent_fg_color"],
    }

    palette = {**gtk_roles, **legacy_roles}
    gtk3_lines = [
        "/* Veyra palette - GTK3; generated by Veyra */",
        "/* Base theme: adw-gtk3 */",
        "",
    ]
    for key, value in palette.items():
        gtk3_lines.append(f"@define-color {key} {sanitize_color(value)};")
    # @define-color declarations alone do not recolor GTK widgets: they are
    # scoped to this user CSS provider and do not replace similarly named colors
    # inside the theme's own provider. Add real widget selectors, changing colors
    # only so that the selected theme keeps its spacing, borders, and geometry.
    gtk3_surface = sanitize_color(mapping["surface"])
    gtk3_surface_container = sanitize_color(mapping["surface_container"])
    gtk3_surface_raised = sanitize_color(mapping["surface_container_high"])
    gtk3_fg = sanitize_color(mapping["on_surface"])
    gtk3_accent = sanitize_color(gtk_roles["accent_bg_color"])
    gtk3_on_accent = sanitize_color(gtk_roles["accent_fg_color"])
    gtk3_outline = sanitize_color(mapping["outline"])
    gtk3_popover = sanitize_color(mapping["surface_container"])
    gtk3_sidebar = sanitize_color(mapping["surface_container"])
    gtk3_lines.extend([
        "",
        "/* Veyra GTK3 widget palette overrides (colors only). */",
        f"window, .background {{ color: {gtk3_fg}; background-color: {gtk3_surface}; }}",
        f"headerbar, .titlebar {{ color: {gtk3_fg}; background-color: {gtk3_surface_container}; }}",
        f"headerbar title, headerbar .title, .titlebar title {{ color: {gtk3_fg}; }}",
        f"button {{ color: {gtk3_fg}; border-color: {gtk3_outline}; }}",
        f"button:not(.flat):not(.suggested-action):not(.destructive-action) {{ background-color: {gtk3_surface_container}; }}",
        f"button:hover:not(.suggested-action):not(.destructive-action) {{ background-color: {gtk3_surface_raised}; }}",
        f"button:checked, button:active, button.suggested-action, .suggested-action {{ color: {gtk3_on_accent}; background-color: {gtk3_accent}; }}",
        f"entry, spinbutton, combobox, textview, treeview.view, .view {{ color: {gtk3_fg}; background-color: {gtk3_surface}; }}",
        f"*:selected, selection {{ color: {gtk3_on_accent}; background-color: {gtk3_accent}; }}",
        f"popover, popover.background, menu, .menu, .context-menu {{ color: {gtk3_fg}; background-color: {gtk3_popover}; }}",
        f".sidebar, .navigation-sidebar {{ color: {gtk3_fg}; background-color: {gtk3_sidebar}; }}",
        f"tooltip, tooltip.background {{ color: {gtk3_fg}; background-color: {gtk3_popover}; }}",
    ])
    gtk3_css = "\n".join(gtk3_lines) + "\n"

    gtk4_lines = [
        "/* Veyra palette - GTK4; generated by Veyra */",
        "/* Base theme: adw-gtk3 / libadwaita */",
        "",
    ]
    for key, value in palette.items():
        gtk4_lines.append(f"@define-color {key} {sanitize_color(value)};")

    gtk4_vars = {
        key.replace("_", "-"): value for key, value in gtk_roles.items()
    }
    gtk4_vars.update({
        "error-color": mapping["error"],
        "warning-bg-color": mapping["tertiary_container"],
        "warning-fg-color": mapping["on_tertiary_container"],
        "warning-color": mapping["tertiary"],
        "success-color": mapping["secondary"],
        "success-bg-color": mapping["secondary_container"],
        "success-fg-color": mapping["on_secondary_container"],
        "shade-color": "rgba(0, 0, 0, 0.36)",
    })

    gtk4_lines.extend(["", "window {"])
    for key, value in gtk4_vars.items():
        css_value = value if key == "shade-color" else sanitize_color(value)
        gtk4_lines.append(f"    --{key}: {css_value};")
    gtk4_lines.append("}")

    # GTK4/libadwaita also needs explicit widget rules; CSS custom properties
    # are not, by themselves, guaranteed to replace the theme's private tokens.
    gtk4_surface = sanitize_color(mapping["surface"])
    gtk4_surface_container = sanitize_color(mapping["surface_container"])
    gtk4_surface_raised = sanitize_color(mapping["surface_container_high"])
    gtk4_fg = sanitize_color(mapping["on_surface"])
    gtk4_accent = sanitize_color(gtk_roles["accent_bg_color"])
    gtk4_on_accent = sanitize_color(gtk_roles["accent_fg_color"])
    gtk4_outline = sanitize_color(mapping["outline"])
    gtk4_lines.extend([
        "",
        "/* Veyra GTK4/libadwaita widget palette overrides (colors only). */",
        f"window, .background {{ color: {gtk4_fg}; background-color: {gtk4_surface}; }}",
        f"headerbar, .titlebar {{ color: {gtk4_fg}; background-color: {gtk4_surface_container}; }}",
        f"headerbar title, headerbar .title, .titlebar title {{ color: {gtk4_fg}; }}",
        f"button {{ color: {gtk4_fg}; border-color: {gtk4_outline}; }}",
        f"button:not(.flat):not(.suggested-action):not(.destructive-action) {{ background-color: {gtk4_surface_container}; }}",
        f"button:hover:not(.suggested-action):not(.destructive-action) {{ background-color: {gtk4_surface_raised}; }}",
        f"button:checked, button.suggested-action, .suggested-action {{ color: {gtk4_on_accent}; background-color: {gtk4_accent}; }}",
        f"entry, spinbutton, combobox, textview, .view, listview row, list row {{ color: {gtk4_fg}; background-color: {gtk4_surface}; }}",
        f"*:selected, selection {{ color: {gtk4_on_accent}; background-color: {gtk4_accent}; }}",
        f"popover, popover > contents, popover.background, menu, .menu {{ color: {gtk4_fg}; background-color: {gtk4_surface_container}; }}",
        f".sidebar, .navigation-sidebar {{ color: {gtk4_fg}; background-color: {gtk4_surface_container}; }}",
    ])
    gtk4_css = "\n".join(gtk4_lines) + "\n"

    gtk3_dir = os.path.join(str(config_home(home)), "gtk-3.0")
    gtk4_dir = os.path.join(str(config_home(home)), "gtk-4.0")
    os.makedirs(gtk3_dir, exist_ok=True)
    os.makedirs(gtk4_dir, exist_ok=True)

    with open(os.path.join(gtk3_dir, "veyra.css"), "w", encoding="utf-8") as f:
        f.write(gtk3_css)
    with open(os.path.join(gtk4_dir, "veyra.css"), "w", encoding="utf-8") as f:
        f.write(gtk4_css)

    def ensure_import(config_dir):
        path = os.path.join(config_dir, "gtk.css")
        import_line = '@import url("veyra.css");'

        # Never write through a symlink into the old theme directory, and
        # never destroy the user's symlink either: move it aside first so the
        # setup stays recoverable.
        if os.path.islink(path):
            backup = path + ".veyra-backup"
            try:
                if os.path.lexists(backup):
                    os.unlink(backup)
                os.rename(path, backup)
                print(f"GTK: {path} was a symlink; moved to {backup} before writing Veyra import.")
            except OSError as exc:
                print(f"GTK: refusing to replace symlink at {path}: {exc}; leaving it untouched.")
                return
            content = ""
        elif os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
        else:
            content = ""

        if import_line not in content:
            content = (
                content.rstrip() + "\n\n" + import_line + "\n"
                if content.strip()
                else import_line + "\n"
            )

        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

    ensure_import(gtk3_dir)
    ensure_import(gtk4_dir)

    # Veyra deliberately uses adw-gtk3 for GTK3 apps. Do not preserve a
    # stale theme preference such as Material-Gnome after the user has selected
    # the Adw theme; wallpaper updates should change only its light/dark variant.
    def theme_is_installed(name):
        roots = (
            os.path.join(str(data_home(home)), "themes"),
            os.path.join(home, ".themes"),
            "/usr/share/themes",
        )
        return any(
            os.path.isfile(os.path.join(root, name, gtk_version, "gtk.css"))
            for root in roots for gtk_version in ("gtk-3.0", "gtk-4.0")
        )

    if theme_is_installed("adw-gtk3"):
        gtk_theme = "adw-gtk3-dark" if is_dark else "adw-gtk3"
    else:
        # Never select Material-Gnome or another broken theme as a fallback.
        gtk_theme = "Adwaita"

    color_scheme = "prefer-dark" if is_dark else "prefer-light"
    opposite_scheme = "prefer-light" if is_dark else "prefer-dark"

    # Keep GTK3's theme setting in settings.ini.
    # GTK4 appearance is synchronized through GSettings below.
    for ini in (
        os.path.join(gtk3_dir, "settings.ini"),
    ):
        if os.path.isfile(ini):
            with open(ini, "r", encoding="utf-8") as f:
                content = f.read()
        else:
            content = "[Settings]\n"

        if re.search(r"(?m)^gtk-theme-name=.*$", content):
            content = re.sub(
                r"(?m)^gtk-theme-name=.*$",
                "gtk-theme-name=" + gtk_theme,
                content,
            )
        elif re.search(r"(?m)^\[Settings\]\s*$", content):
            content = re.sub(
                r"(?m)^\[Settings\]\s*$",
                "[Settings]\ngtk-theme-name=" + gtk_theme,
                content,
                count=1,
            )
        else:
            content += "\n[Settings]\ngtk-theme-name=" + gtk_theme + "\n"

        # Keep the dark preference in sync without disturbing other settings.
        dark_setting = "gtk-application-prefer-dark-theme=" + ("1" if is_dark else "0")
        if re.search(r"(?m)^gtk-application-prefer-dark-theme=.*$", content):
            content = re.sub(
                r"(?m)^gtk-application-prefer-dark-theme=.*$",
                dark_setting,
                content,
            )
        elif re.search(r"(?m)^\[Settings\]\s*$", content):
            content = re.sub(
                r"(?m)^\[Settings\]\s*$",
                "[Settings]\n" + dark_setting,
                content,
                count=1,
            )
        else:
            content = content.rstrip() + "\n\n[Settings]\n" + dark_setting + "\n"

        with open(ini, "w", encoding="utf-8") as f:
            f.write(content)

    # GTK4/libadwaita applications use the native Adwaita styling and the
    # org.gnome.desktop.interface color-scheme preference. If an old GTK4
    # settings file explicitly points at the broken Material-Gnome theme, reset
    # just that stale key to Adwaita, preserving all other user settings.
    gtk4_ini = os.path.join(gtk4_dir, "settings.ini")
    if os.path.isfile(gtk4_ini):
        with open(gtk4_ini, "r", encoding="utf-8") as f:
            content = f.read()
        updated, count = re.subn(
            r"(?mi)^gtk-theme-name\s*=\s*Material-Gnome(?:[^\r\n]*)$",
            "gtk-theme-name=Adwaita",
            content,
        )
        if count:
            with open(gtk4_ini, "w", encoding="utf-8") as f:
                f.write(updated)

    # Sync GNOME-compatible theme settings and dark/light preference.
    subprocess.run(
        ["gsettings", "set", "org.gnome.desktop.interface",
         "gtk-theme", gtk_theme],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        ["gsettings", "set", "org.gnome.desktop.interface",
         "color-scheme", opposite_scheme],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        ["gsettings", "set", "org.gnome.desktop.interface",
         "color-scheme", color_scheme],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )

    xsettings = os.path.join(str(config_home(home)), "xsettingsd", "xsettingsd.conf")
    if os.path.isfile(xsettings):
        with open(xsettings, "r", encoding="utf-8") as f:
            content = f.read()
        updated, count = re.subn(
            r'(?m)^Net/ThemeName\s+.*$',
            'Net/ThemeName "' + gtk_theme + '"',
            content,
            count=1,
        )
        if count:
            with open(xsettings, "w", encoding="utf-8") as f:
                f.write(updated)
            subprocess.run(
                ["killall", "-HUP", "xsettingsd"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
