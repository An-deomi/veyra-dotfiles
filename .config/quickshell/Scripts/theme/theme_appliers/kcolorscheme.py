import os
import subprocess

from xdg_paths import config_home, data_home


def apply(home, colors):
    def rgb(value):
        value = str(value).lstrip("#")[:6]
        return ",".join(str(int(value[i:i + 2], 16)) for i in (0, 2, 4))

    bg = colors["bg"]
    fg = colors["fg"]
    primary = colors.get("m3_primary", colors["accent"])
    on_primary = colors.get("m3_on_primary", bg)
    surface = colors.get("m3_surface_container", colors["bgSecondary"])
    raised = colors.get("m3_surface_container_high", surface)
    outline = colors.get("m3_outline", colors["border"])
    tertiary = colors.get("m3_tertiary", colors["accentComplementary"])
    error = colors.get("m3_error", "#ffb4ab")
    muted = colors.get("m3_on_surface_variant", colors["muted"])

    sections = {
        "ColorEffects:Disabled": {"Color": rgb(bg), "ColorAmount": "0", "ColorEffect": "0", "ContrastAmount": "0.65", "ContrastEffect": "1", "IntensityAmount": "0.1", "IntensityEffect": "2"},
        "ColorEffects:Inactive": {"ChangeSelectionColor": "true", "Color": rgb(muted), "ColorAmount": "0.025", "ColorEffect": "2", "ContrastAmount": "0.1", "ContrastEffect": "2", "Enable": "false", "IntensityAmount": "0", "IntensityEffect": "0"},
    }
    roles = {
        "Button": (raised, surface, fg),
        "Complementary": (bg, surface, primary),
        "Header": (surface, bg, fg),
        "Header][Inactive": (surface, bg, fg),
        "Selection": (primary, surface, on_primary),
        "Tooltip": (surface, bg, fg),
        "View": (surface, bg, fg),
        "Window": (surface, bg, fg),
    }
    for section, (alternate, background, text) in roles.items():
        sections["Colors:" + section] = {
            "BackgroundAlternate": rgb(alternate),
            "BackgroundNormal": rgb(background),
            "DecorationFocus": rgb(primary),
            "DecorationHover": rgb(primary),
            "ForegroundActive": rgb(primary),
            "ForegroundInactive": rgb(muted),
            "ForegroundLink": rgb(primary),
            "ForegroundNegative": rgb(error),
            "ForegroundNeutral": rgb(tertiary),
            "ForegroundNormal": rgb(text),
            "ForegroundPositive": rgb(tertiary),
            "ForegroundVisited": rgb(muted),
        }
    sections["Colors:Selection"].update({
        "BackgroundNormal": rgb(primary),
        "ForegroundNormal": rgb(on_primary),
        "ForegroundActive": rgb(on_primary),
    })
    sections["General"] = {"ColorScheme": "Veyra", "Name": "Veyra"}
    sections["KDE"] = {"contrast": "4"}
    sections["WM"] = {
        "activeBackground": rgb(primary),
        "activeBlend": rgb(on_primary),
        "activeForeground": rgb(on_primary),
        "inactiveBackground": rgb(bg),
        "inactiveBlend": rgb(muted),
        "inactiveForeground": rgb(muted),
    }
    output = []
    for section, values in sections.items():
        output.append("[" + section + "]")
        output.extend(key + "=" + value for key, value in values.items())
        output.append("")
    directory = os.path.join(str(data_home(home)), "color-schemes")
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, "Veyra.colors")
    with open(path, "w", encoding="utf-8") as file:
        file.write("\n".join(output))

    subprocess.run(
        [
            "kwriteconfig6",
            "--file", os.path.join(str(config_home(home)), "kdeglobals"),
            "--group", "General",
            "--key", "ColorScheme",
            "Veyra",
        ],
        check=False,
    )
    subprocess.run(
        [
            "kwriteconfig6",
            "--file", os.path.join(str(config_home(home)), "kdeglobals"),
            "--group", "UiSettings",
            "--key", "ColorScheme",
            "Veyra",
        ],
        check=False,
    )
    print("Generated KDE color scheme:", path)
