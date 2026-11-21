#!/usr/bin/env python3
import sys
sys.dont_write_bytecode = True

import configparser
import json
import re
import subprocess
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print("Usage: apply_font.py <FontName> <FontSize>", file=sys.stderr)
        sys.exit(1)

    font_name = sys.argv[1]
    try:
        font_size = int(sys.argv[2])
        if not 1 <= font_size <= 200:
            raise ValueError()
    except ValueError:
        print("Font size must be between 1 and 200", file=sys.stderr)
        sys.exit(1)

    if not font_name.strip() or any(c in font_name for c in "\n\r"):
        print("Invalid font name", file=sys.stderr)
        sys.exit(1)

    home = Path.home()
    full_font = f"{font_name} {font_size}"

    subprocess.run(
        ["gsettings", "set", "org.gnome.desktop.interface", "font-name", full_font],
        capture_output=True,
    )

    for gtk_ver in ["gtk-3.0", "gtk-4.0"]:
        ini_path = home / ".config" / gtk_ver / "settings.ini"
        if ini_path.is_file():
            try:
                lines = ini_path.read_text(encoding="utf-8").splitlines(keepends=True)
                new_lines = []
                found = False
                for line in lines:
                    if line.startswith("gtk-font-name="):
                        new_lines.append(f"gtk-font-name={full_font}\n")
                        found = True
                    else:
                        new_lines.append(line)
                if not found:
                    new_lines.append(f"gtk-font-name={full_font}\n")
                ini_path.write_text("".join(new_lines), encoding="utf-8")
            except Exception as exc:
                print(f"Warning: Failed to update {ini_path}: {exc}", file=sys.stderr)

    for qtct in ["qt5ct", "qt6ct"]:
        qtct_conf = home / ".config" / qtct / f"{qtct}.conf"
        if qtct_conf.is_file():
            try:
                config = configparser.ConfigParser()
                config.optionxform = str
                config.read(qtct_conf, encoding="utf-8")
                if "Fonts" not in config:
                    config["Fonts"] = {}
                font_str = f"{font_name},{font_size},-1,5,50,0,0,0,0,0"
                config["Fonts"]["general"] = f'"{font_str}"'
                with open(qtct_conf, "w", encoding="utf-8") as handle:
                    config.write(handle)
            except Exception as exc:
                print(f"Warning: Failed to update {qtct_conf}: {exc}", file=sys.stderr)

    updater = (
        Path(__file__).resolve().parents[2]
        / "Core" / "Services" / "scripts" / "update_hypr_prefs.py"
    )
    if not updater.is_file():
        print(f"Hyprland preference updater not found: {updater}", file=sys.stderr)
        sys.exit(1)

    args = {
        "group": {
            "groupbar": {
                "font_family": f'"{font_name}"',
                "font_size": font_size,
            }
        }
    }
    result = subprocess.run(
        [sys.executable, str(updater), json.dumps(args)],
        capture_output=True, text=True,
    )
    if result.returncode:
        print(result.stderr or result.stdout, file=sys.stderr)
        sys.exit(result.returncode)

    subprocess.run(["hyprctl", "reload"], check=False)

    kitty_conf = home / ".config" / "kitty" / "kitty.conf"
    if kitty_conf.is_file():
        try:
            content = kitty_conf.read_text(encoding="utf-8")
            new_content, count = re.subn(
                r"^font_size\s+.*",
                f"font_size {font_size}",
                content,
                flags=re.MULTILINE,
            )
            if count:
                kitty_conf.write_text(new_content, encoding="utf-8")
                subprocess.run(["killall", "-USR1", "kitty"], stderr=subprocess.DEVNULL)
        except Exception as exc:
            print(f"Warning: Failed to update Kitty font: {exc}", file=sys.stderr)

if __name__ == "__main__":
    main()
