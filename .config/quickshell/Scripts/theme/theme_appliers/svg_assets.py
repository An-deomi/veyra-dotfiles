import os

from xdg_paths import config_home, data_home
import re

from color_utils import sanitize_color


def apply(home, colors):
    accent = colors["accent"]
    accentComplementary = colors["accentComplementary"]

    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets_dir = os.path.join(os.path.dirname(script_dir), "assets")
    if not os.path.exists(assets_dir):
        assets_dir = os.path.join(str(config_home(home)), "quickshell", "assets")

    # Never rewrite the repo-shipped assets: write wallpaper-colored copies
    # into $XDG_DATA_HOME/veyra/assets instead. SvgIcon prefers those and
    # falls back to the pristine shipped defaults.
    output_dir = data_home(home) / "veyra" / "assets"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Mirror every shipped icon, not only the gradient ones. SvgIcon probes the
    # data dir first for all icons, so an incomplete mirror makes the remaining
    # icons fail to load, log a warning and reload from the shipped assets.
    if os.path.exists(assets_dir):
        for svg_file in sorted(f for f in os.listdir(assets_dir) if f.endswith(".svg")):
            svg_path = os.path.join(assets_dir, svg_file)
            if not os.path.exists(svg_path):
                continue
            with open(svg_path, "r") as f2:
                content = f2.read()

            new_content = re.sub(
                r'(<stop\s+offset="0%"\s+stop-color=")[^"]+(")',
                f"\\g<1>{sanitize_color(accent)}\\g<2>",
                content,
            )
            new_content = re.sub(
                r'(<stop\s+offset="100%"\s+stop-color=")[^"]+(")',
                f"\\g<1>{sanitize_color(accentComplementary)}\\g<2>",
                new_content,
            )

            target = output_dir / svg_file
            if (not target.exists()) or (target.read_text(encoding="utf-8") != new_content):
                target.write_text(new_content, encoding="utf-8")
