import os
import shutil
import subprocess

from color_utils import sanitize_color
from theme_appliers.file_utils import atomic_write_text
from xdg_paths import config_home, is_live_session


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
    atomic_write_text(os.path.join(kitty_dir, "theme.conf"), kitty_theme)
    if not is_live_session(home):
        return

    # Reload running kitty instances without a shell string.
    if shutil.which("pkill"):
        try:
            subprocess.run(["pkill", "-USR1", "-x", "kitty"], check=False, timeout=3)
        except (OSError, subprocess.SubprocessError):
            pass

    # Also broadcast OSC 4/10/11/12 palette updates to running Foot and other
    # terminal emulator PTYs so open terminals recolor live on wallpaper change.
    _broadcast_osc_palette(
        fg=sanitize_color(fg),
        bg=sanitize_color(bg),
        cursor=sanitize_color(fg),
        palette=[
            sanitize_color(border),
            sanitize_color(accentComplementary),
            sanitize_color(accent),
            sanitize_color(accentComplementary),
            sanitize_color(accent),
            sanitize_color(accentComplementary),
            sanitize_color(accent),
            sanitize_color(overlayBase),
            sanitize_color(muted),
            sanitize_color(accentComplementary),
            sanitize_color(accent),
            sanitize_color(accentComplementary),
            sanitize_color(accent),
            sanitize_color(accentComplementary),
            sanitize_color(accent),
            sanitize_color(fg),
        ],
    )


_LIVE_OSC_TERMINALS = {"foot", "footclient", "alacritty", "wezterm-gui", "ghostty", "konsole"}


def _is_terminal_pty(pts_path: str, uid: int) -> bool:
    try:
        st = os.stat(pts_path)
    except OSError:
        return False
    if st.st_uid != uid:
        return False
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            if os.readlink(f"/proc/{entry}/fd/0") != pts_path:
                continue
            with open(f"/proc/{entry}/status", "r", encoding="utf-8", errors="ignore") as f:
                ppid = ""
                for line in f:
                    if line.startswith("PPid:"):
                        ppid = line.split(":", 1)[1].strip()
                        break
            if ppid:
                with open(f"/proc/{ppid}/comm", "r", encoding="utf-8", errors="ignore") as f:
                    if f.read().strip() in _LIVE_OSC_TERMINALS:
                        return True
        except OSError:
            continue
    return False


def _broadcast_osc_palette(fg: str, bg: str, cursor: str, palette: list[str]) -> None:
    if not os.path.isdir("/dev/pts"):
        return
    uid = os.getuid()
    seq = f"\033]10;{fg}\033\\\033]11;{bg}\033\\\033]12;{cursor}\033\\"
    for idx, color in enumerate(palette):
        seq += f"\033]4;{idx};{color}\033\\"
    payload = seq.encode("ascii", errors="ignore")
    for name in os.listdir("/dev/pts"):
        if not name.isdigit():
            continue
        pts_path = f"/dev/pts/{name}"
        if not _is_terminal_pty(pts_path, uid):
            continue
        fd = -1
        try:
            fd = os.open(pts_path, os.O_WRONLY | os.O_NONBLOCK | os.O_NOCTTY)
            os.write(fd, payload)
        except OSError:
            pass
        finally:
            if fd >= 0:
                try:
                    os.close(fd)
                except OSError:
                    pass
