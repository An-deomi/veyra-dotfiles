#!/usr/bin/env python3
"""Manage user-owned Veyra color presets with atomic, private writes."""
from __future__ import annotations
import json
import os
import re
import sys
import tempfile
import unicodedata
from pathlib import Path


def preset_dir() -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()
    return config_home / "quickshell" / "theme-presets"


def slugify(name: str) -> str:
    raw = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", raw).strip("-")
    if not slug:
        raise ValueError("Choose a name containing letters or numbers.")
    return slug[:48]


def clean_palette(raw: object) -> dict:
    if not isinstance(raw, dict):
        raise ValueError("Palette must be a JSON object.")
    clean = {}
    for key in ("bg", "fg", "accent", "accentComplementary"):
        value = str(raw.get(key, "")).strip()
        if not re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", value):
            raise ValueError(f"Invalid {key} color; expected #RRGGBB or #RRGGBBAA.")
        clean[key] = value
    return clean


def atomic_write(path: Path, payload: dict, private_parent: bool = True) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700 if private_parent else 0o755)
    if private_parent:
        os.chmod(path.parent, 0o700)
    fd, temp_name = tempfile.mkstemp(prefix=".theme-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(payload, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temp_name, 0o600)
        os.replace(temp_name, path)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass


def list_presets() -> list[dict]:
    folder = preset_dir()
    output = []
    if not folder.exists():
        print("[]")
        return []
    for path in sorted(folder.glob("*.json"), key=lambda p: p.name.casefold()):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            palette = clean_palette(data)
            output.append({"id": path.stem, "name": str(data.get("name") or path.stem), **palette})
        except (OSError, ValueError, json.JSONDecodeError):
            continue
    print(json.dumps(output, ensure_ascii=False))
    return output


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: theme_preset_manager.py list | save <name> <palette-json> | delete <id> | import <file> | export <name> <palette-json> <file>", file=sys.stderr)
        return 2
    command = argv[1]
    folder = preset_dir()
    if command == "list":
        list_presets()
        return 0
    if command == "save" and len(argv) == 4:
        name = argv[2].strip()
        if not name or len(name) > 48:
            raise ValueError("Theme names must contain 1–48 characters.")
        palette = clean_palette(json.loads(argv[3]))
        theme_id = slugify(name)
        atomic_write(folder / f"{theme_id}.json", {"name": name, **palette})
        print(json.dumps({"ok": True, "id": theme_id, "name": name}))
        return 0
    if command == "delete" and len(argv) == 3:
        theme_id = argv[2]
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,47}", theme_id):
            raise ValueError("Invalid theme preset identifier.")
        path = folder / f"{theme_id}.json"
        try:
            path.unlink()
        except FileNotFoundError:
            raise ValueError("Theme preset no longer exists.")
        print(json.dumps({"ok": True, "deleted": theme_id}))
        return 0
    if command == "import" and len(argv) == 3:
        source = Path(argv[2]).expanduser()
        if not source.is_file():
            raise ValueError("Selected palette file does not exist.")
        data = json.loads(source.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("Palette file must contain a JSON object.")
        name = str(data.get("name") or source.stem).strip()
        if not name or len(name) > 48:
            raise ValueError("Imported palette name must contain 1–48 characters.")
        palette = clean_palette(data)
        theme_id = slugify(name)
        atomic_write(folder / f"{theme_id}.json", {"name": name, **palette})
        print(json.dumps({"ok": True, "id": theme_id, "name": name, "imported": True}))
        return 0
    if command == "export" and len(argv) == 5:
        name = argv[2].strip()
        if not name or len(name) > 48:
            raise ValueError("Theme names must contain 1–48 characters.")
        palette = clean_palette(json.loads(argv[3]))
        target = Path(argv[4]).expanduser()
        if target.suffix.lower() != ".json":
            raise ValueError("Choose a .json file for the palette export.")
        atomic_write(target, {"name": name, **palette}, private_parent=False)
        print(json.dumps({"ok": True, "path": str(target), "exported": True}))
        return 0
    raise ValueError("Invalid theme preset command or arguments.")


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
