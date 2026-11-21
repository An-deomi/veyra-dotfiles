import json
import subprocess


def generate(accent, is_dark):
    mode = "dark" if is_dark else "light"
    command = [
        "matugen", "color", "hex", accent,
        "--type", "scheme-tonal-spot",
        "--mode", mode,
        "--json", "hex",
        "--dry-run",
    ]
    result = subprocess.run(
        command, capture_output=True, text=True, check=True, timeout=15
    )
    output = result.stdout
    start = output.find("{")
    if start < 0:
        raise ValueError("Matugen did not return JSON color data")
    data = json.loads(output[start:])
    palette = data["colors"]
    variant = "dark" if is_dark else "light"
    semantic = {}
    for name, values in palette.items():
        entry = values.get(variant, values.get("default", {}))
        color = entry.get("color")
        if color:
            semantic["m3_" + name] = color
    return semantic
