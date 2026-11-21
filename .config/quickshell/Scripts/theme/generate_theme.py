#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import tempfile

from xdg_paths import cache_home, state_home
from theme_extractors.image_utils import prepare_image
from theme_extractors.magick_utils import extract_histogram_colors, get_brightness
from theme_extractors.palette import generate_palette


def write_json_atomic(path, data):
    """Write palette JSON atomically so FileView never reads a partial file."""
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".palette-", suffix=".tmp", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        try:
            if os.path.exists(temporary):
                os.unlink(temporary)
        except OSError:
            pass


def main():
    if len(sys.argv) < 2:
        print("Usage: generate_theme.py <image_path>")
        sys.exit(1)

    image_path = sys.argv[1]
    if not os.path.exists(image_path):
        print(f"Error: image not found: {image_path}")
        sys.exit(1)

    processing_path, magick_path = prepare_image(image_path)
    brightness = get_brightness(magick_path)
    is_dark = brightness <= 0.4

    histogram_colors = extract_histogram_colors(magick_path)
    if not histogram_colors:
        print("Error: ImageMagick returned no colors.")
        sys.exit(1)

    generated_dark, generated_light = generate_palette(histogram_colors)
    if not generated_dark:
        print("Error processing colors.")
        sys.exit(1)

    cache_dir = os.path.join(str(cache_home()), "quickshell")
    os.makedirs(cache_dir, exist_ok=True)

    # Active scheme is user state; wallpaper variants are regenerable cache.
    state_dir = os.path.join(str(state_home()), "veyra")
    os.makedirs(state_dir, exist_ok=True)

    wallpaper_file_dark = os.path.join(cache_dir, "wallpaper_colorscheme_dark.json")
    write_json_atomic(wallpaper_file_dark, generated_dark)

    wallpaper_file_light = os.path.join(cache_dir, "wallpaper_colorscheme_light.json")
    write_json_atomic(wallpaper_file_light, generated_light)

    active_file = os.path.join(state_dir, "colorscheme.json")
    legacy_active_file = os.path.join(cache_dir, "colorscheme.json")
    read_file = active_file if os.path.exists(active_file) else legacy_active_file
    should_write_active = True
    user_is_dark = is_dark

    if os.path.exists(read_file):
        try:
            with open(read_file, "r") as f:
                curr_data = json.load(f)
                should_write_active = curr_data.get("generateFromWallpaper", False)
                if "wallpaperIsDark" in curr_data:
                    user_is_dark = curr_data["wallpaperIsDark"]
        except Exception:
            pass

    if len(sys.argv) >= 3:
        should_write_active = sys.argv[2].lower() in ["true", "1", "yes"]

    active_generated = dict(generated_dark if user_is_dark else generated_light)
    active_generated["wallpaperIsDark"] = user_is_dark

    wallpaper_file = os.path.join(cache_dir, "wallpaper_colorscheme.json")
    write_json_atomic(wallpaper_file, active_generated)

    if should_write_active:
        write_json_atomic(active_file, active_generated)
        print("Success: Generated colorscheme.json and wallpaper variants")
    else:
        print("Success: Generated wallpaper variants (active colorscheme preserved)")

    print(
        "COLORS:"
        + json.dumps(
            {
                "dark": generated_dark,
                "light": generated_light,
                "activeIsDark": user_is_dark,
            }
        )
    )


if __name__ == "__main__":
    main()
