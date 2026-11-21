import os
import subprocess

from xdg_paths import config_home

from color_utils import sanitize_color


def apply(home, colors):
    bg = colors["bg"]
    fg = colors["fg"]
    accent = colors["accent"]
    accentComplementary = colors["accentComplementary"]
    # The state file stores muted/border with alpha (#AARRGGBB) which
    # sanitize_color flattens to raw fg; use the opaque overlayBase steel
    # (= fg/ accent blend, already an opaque palette token) for neutral slots.
    muted = colors.get("overlayBase", colors.get("muted", "#888888"))
    border = colors.get("overlayBase", colors.get("border", "#888888"))
    bgSecondary = colors["bgSecondary"]
    bgTertiary = colors.get("bgTertiary", bgSecondary)
    bgAccent = colors.get("bgAccent", accent)
    bgAccentComplementary = colors.get("bgAccentComplementary", accentComplementary)
    overlayBase = colors.get("overlayBase", accent)

    kitty_theme = f"""foreground              {sanitize_color(fg)}
background              {sanitize_color(bg)}
selection_foreground    {sanitize_color(bg)}
selection_background    {sanitize_color(accent)}
cursor                  {sanitize_color(fg)}
cursor_text_color       {sanitize_color(bg)}
url_color               {sanitize_color(accentComplementary)}
active_border_color     {sanitize_color(accent)}
inactive_border_color   {sanitize_color(border)}
bell_border_color       {sanitize_color(accentComplementary)}
active_tab_foreground   {sanitize_color(bg)}
active_tab_background   {sanitize_color(accent)}
inactive_tab_foreground {sanitize_color(muted)}
inactive_tab_background {sanitize_color(bgSecondary)}
tab_bar_background      {sanitize_color(bg)}
# Semantic slots so TUIs stay readable: ok = accent, attention = complementary,
# neutral = fg/muted. Not a literal srgb ramp — the generator only knows the
# wallpaper palette; keep the shape consistent between normal and bright.
color0  {sanitize_color(border)}
color8  {sanitize_color(muted)}
color1  {sanitize_color(accentComplementary)}
color9  {sanitize_color(accentComplementary)}
color2  {sanitize_color(accent)}
color10 {sanitize_color(accent)}
color3  {sanitize_color(accentComplementary)}
color11 {sanitize_color(accentComplementary)}
color4  {sanitize_color(accent)}
color12 {sanitize_color(accent)}
color5  {sanitize_color(accentComplementary)}
color13 {sanitize_color(accentComplementary)}
color6  {sanitize_color(accent)}
color14 {sanitize_color(accent)}
color7  {sanitize_color(overlayBase)}
color15 {sanitize_color(fg)}
color16 {sanitize_color(accent)}
color17 {sanitize_color(accentComplementary)}
color18 {sanitize_color(accent)}
color19 {sanitize_color(accentComplementary)}
color20 {sanitize_color(accent)}
color21 {sanitize_color(accentComplementary)}
"""
    kitty_dir = os.path.join(str(config_home(home)), "kitty")
    os.makedirs(kitty_dir, exist_ok=True)
    with open(os.path.join(kitty_dir, "theme.conf"), "w") as f2:
        f2.write(kitty_theme)
    # Reload running kitty instances without a shell string.
    subprocess.run(["pkill", "-USR1", "-x", "kitty"], check=False)
