#!/usr/bin/env python3
"""Safe, user-owned Veyra custom template importer and renderer.

Supports Noctalia community template folders (template.toml, static input_path / output_path)
plus standalone files with an explicitly supplied output path. Shell hooks are never executed.
"""
from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
import urllib.parse
from pathlib import Path, PurePosixPath
from typing import Any

sys.dont_write_bytecode = True

from xdg_paths import cache_home, config_home, data_home, is_live_session, state_home

SCRIPT_DIR = Path(__file__).resolve().parent
# Shipped templates live beside the application source. Imported templates and
# their edits belong in the user's data directory, never inside a Git checkout.
BUNDLED_TEMPLATE_ROOT = SCRIPT_DIR.parents[1] / "custom_templates"


def _bind_home(home: str | Path | None = None) -> None:
    global HOME, CONFIG_HOME, DATA_HOME, CACHE_HOME, STATE_HOME
    global USER_TEMPLATE_ROOT, LEGACY_TEMPLATE_ROOT, TEMPLATE_ROOT, TEMPLATE_STATE_ROOT
    HOME = Path(home or os.environ.get("HOME") or Path.home()).expanduser().resolve(strict=False)
    CONFIG_HOME = config_home(HOME).resolve(strict=False)
    DATA_HOME = data_home(HOME).resolve(strict=False)
    CACHE_HOME = cache_home(HOME).resolve(strict=False)
    STATE_HOME = state_home(HOME).resolve(strict=False)
    USER_TEMPLATE_ROOT = DATA_HOME / "veyra/custom_templates"
    LEGACY_TEMPLATE_ROOT = CONFIG_HOME / "quickshell/custom_templates"
    TEMPLATE_ROOT = USER_TEMPLATE_ROOT  # compatibility name for import destinations
    TEMPLATE_STATE_ROOT = STATE_HOME / "veyra/custom_templates"


_bind_home()
MAX_DOWNLOAD = 40 * 1024 * 1024
MAX_TOTAL_FILES = 300
MAX_SINGLE_FILE = 8 * 1024 * 1024
EXPR_RE = re.compile(r"{{\s*(.*?)\s*}}", re.DOTALL)
SAFE_ID_RE = re.compile(r"[^a-z0-9]+")

class TemplateError(Exception):
    pass


def emit(message: str, error: bool = False) -> None:
    print(message, file=sys.stderr if error else sys.stdout, flush=True)


def slugify(value: str) -> str:
    value = SAFE_ID_RE.sub("-", value.lower()).strip("-")
    return value[:60] or "custom-template"


def packaged_template_ids() -> set[str]:
    manifest = BUNDLED_TEMPLATE_ROOT / ".veyra-bundled.json"
    data = read_json(manifest, [])
    if isinstance(data, list):
        return {item for item in data if isinstance(item, str)}
    return set()


def template_roots() -> list[Path]:
    roots = [USER_TEMPLATE_ROOT, BUNDLED_TEMPLATE_ROOT]
    try:
        legacy = LEGACY_TEMPLATE_ROOT.resolve()
    except OSError:
        legacy = LEGACY_TEMPLATE_ROOT
    if all(legacy != root.resolve() for root in roots if root.exists()):
        roots.append(LEGACY_TEMPLATE_ROOT)
    return roots


def migrate_legacy_user_templates() -> None:
    """Move old user imports out of the checkout while preserving bundled assets."""
    try:
        same_as_bundled = LEGACY_TEMPLATE_ROOT.resolve() == BUNDLED_TEMPLATE_ROOT.resolve()
    except OSError:
        same_as_bundled = LEGACY_TEMPLATE_ROOT == BUNDLED_TEMPLATE_ROOT
    if not same_as_bundled or not LEGACY_TEMPLATE_ROOT.is_dir():
        return
    bundled_ids = packaged_template_ids()
    for folder in LEGACY_TEMPLATE_ROOT.iterdir():
        if not folder.is_dir() or folder.name.startswith(".") or folder.name in bundled_ids:
            continue
        meta = read_json(folder / "template.json")
        template_id = meta.get("id") if isinstance(meta, dict) else None
        if not isinstance(template_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,80}", template_id):
            continue
        USER_TEMPLATE_ROOT.mkdir(parents=True, exist_ok=True)
        destination = USER_TEMPLATE_ROOT / template_id
        if destination.exists():
            continue
        try:
            shutil.move(str(folder), str(destination))
        except OSError:
            # Keep the old folder usable rather than failing all template loading.
            continue


def iter_template_folders():
    migrate_legacy_user_templates()
    seen: set[str] = set()
    for root in template_roots():
        if not root.is_dir():
            continue
        for folder in sorted(root.iterdir()):
            if not folder.is_dir():
                continue
            meta = read_json(folder / "template.json")
            template_id = meta.get("id") if isinstance(meta, dict) else None
            if not isinstance(template_id, str) or template_id in seen:
                continue
            seen.add(template_id)
            yield folder


def unique_id(base: str) -> str:
    candidate = slugify(base)
    n = 2
    while any((root / candidate).exists() for root in template_roots()):
        candidate = f"{slugify(base)[:54]}-{n}"
        n += 1
    return candidate


def read_json(path: Path, default: Any = None) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def save_metadata(folder: Path, metadata: dict[str, Any]) -> None:
    """Write portable, static template metadata (never runtime install state)."""
    portable = {key: value for key, value in metadata.items() if key not in {"enabled", "backups", "last_hashes"}}
    tmp = folder / "template.json.tmp"
    tmp.write_text(json.dumps(portable, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(folder / "template.json")


def template_state_path(template_id: str) -> Path:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,80}", template_id):
        raise TemplateError("Invalid template ID for local state.")
    return TEMPLATE_STATE_ROOT / (template_id + ".json")


def save_template_state(template_id: str, state: dict[str, Any]) -> None:
    path = template_state_path(template_id)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        path.parent.chmod(0o700)
    except OSError:
        pass
    fd, tmp_name = tempfile.mkstemp(prefix="." + template_id + "-", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            os.chmod(tmp_name, 0o600)
            json.dump(state, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp_name, path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def read_template_state(folder: Path, metadata: dict[str, Any]) -> dict[str, Any]:
    """Read user-local install state and migrate old embedded state once."""
    template_id = str(metadata.get("id", folder.name))
    state_path = template_state_path(template_id)
    state = read_json(state_path)
    if isinstance(state, dict):
        return {
            "enabled": bool(state.get("enabled", False)),
            "backups": state.get("backups", {}) if isinstance(state.get("backups", {}), dict) else {},
            "last_hashes": state.get("last_hashes", {}) if isinstance(state.get("last_hashes", {}), dict) else {},
        }
    legacy = {
        "enabled": bool(metadata.get("enabled", metadata.get("default_enabled", False))),
        "backups": metadata.get("backups", {}) if isinstance(metadata.get("backups", {}), dict) else {},
        "last_hashes": metadata.get("last_hashes", {}) if isinstance(metadata.get("last_hashes", {}), dict) else {},
    }
    if any(key in metadata for key in ("enabled", "backups", "last_hashes")):
        save_template_state(template_id, legacy)
        # Immediately remove the non-portable legacy state from the tracked template file.
        save_metadata(folder, metadata)
    return legacy


def safe_copy_tree(source: Path, destination: Path) -> None:
    source = source.resolve(strict=True)
    count = 0
    total = 0
    for item in source.rglob("*"):
        rel = item.relative_to(source)
        if any(part in {".git", "__pycache__", ".venv", "node_modules"} for part in rel.parts):
            continue
        if item.is_symlink():
            continue
        if item.is_dir():
            continue
        if not item.is_file():
            continue
        size = item.stat().st_size
        if size > MAX_SINGLE_FILE:
            raise TemplateError(f"Refusing large template file: {rel} ({size} bytes).")
        total += size
        count += 1
        if count > MAX_TOTAL_FILES or total > MAX_DOWNLOAD:
            raise TemplateError("Template folder is too large (file or total-size limit reached).")
        target = destination / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(item, target)
    if count == 0:
        raise TemplateError("The selected folder contains no regular template files.")


def fetch_bytes(url: str, max_bytes: int = MAX_DOWNLOAD) -> bytes:
    import urllib.error
    import urllib.request
    req = urllib.request.Request(url, headers={"User-Agent": "Veyra-Custom-Template-Importer/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as response:
            data = response.read(max_bytes + 1)
    except (OSError, urllib.error.URLError, urllib.error.HTTPError) as exc:
        raise TemplateError(f"Download failed: {exc}") from exc
    if len(data) > max_bytes:
        raise TemplateError("Download is larger than the allowed size limit.")
    return data


def github_url_info(url: str) -> tuple[str, str, str, str] | None:
    parsed = urllib.parse.urlparse(url)
    host = (parsed.hostname or "").lower()
    parts = [urllib.parse.unquote(p) for p in parsed.path.strip("/").split("/") if p]
    if host == "github.com" and len(parts) >= 5 and parts[2] in {"tree", "blob"}:
        owner, repo, kind, branch = parts[:4]
        rel = "/".join(parts[4:])
        return owner, repo, branch, (kind + ":" + rel)
    if host == "raw.githubusercontent.com" and len(parts) >= 4:
        owner, repo, branch = parts[:3]
        rel = "/".join(parts[3:])
        return owner, repo, branch, "raw:" + rel
    return None


def create_official_builtin_manifest(owner: str, repo: str, branch: str, rel_folder: str, destination: Path) -> None:
    """Adapt a static template from Noctalia's built-in catalog without importing/running hooks."""
    parts = PurePosixPath(rel_folder).parts
    if owner.lower() != "noctalia-dev" or repo.lower() != "noctalia":
        return
    if len(parts) != 3 or parts[:2] != ("assets", "templates"):
        return
    template_id = parts[2]
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,80}", template_id):
        return
    if (destination / "template.toml").is_file():
        return

    catalog_url = (
        f"https://raw.githubusercontent.com/{owner}/{repo}/"
        f"{urllib.parse.quote(branch, safe='')}/assets/templates/builtin.toml"
    )
    try:
        catalog_text = fetch_bytes(catalog_url, 2 * 1024 * 1024).decode("utf-8")
        catalog_data = tomllib.loads(catalog_text)
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as exc:
        raise TemplateError(f"Could not read Noctalia's built-in template catalog: {exc}") from exc

    catalog = catalog_data.get("catalog", {}).get(template_id)
    config = catalog_data.get("templates", {}).get(template_id)
    if not isinstance(catalog, dict) or not isinstance(config, dict):
        return

    # Only static templates are supported here. Command-based paths are never run.
    if config.get("input_path_dynamic") or config.get("output_path_dynamic"):
        raise TemplateError(
            f"Noctalia's built-in '{template_id}' template uses a dynamic command-based path, "
            "which Veyra intentionally will not execute."
        )
    input_path = config.get("input_path")
    output_path = config.get("output_path")
    if not isinstance(input_path, str) or not input_path.strip() or not output_path:
        return

    root_input_parts = PurePosixPath(input_path).parts
    selected_parts = (template_id,)
    if ".." in root_input_parts or not root_input_parts or root_input_parts[:1] != selected_parts:
        raise TemplateError("The official template input is outside the selected template folder.")
    local_input = PurePosixPath(*root_input_parts[1:])
    if not local_input.parts or local_input.is_absolute() or ".." in local_input.parts:
        raise TemplateError("The official template has an unsafe input path.")
    input_file = destination / local_input
    if not input_file.is_file():
        raise TemplateError(f"Official template input file was not found in the selected folder: {local_input}")

    if isinstance(output_path, list):
        if not all(isinstance(item, str) and item.strip() for item in output_path):
            raise TemplateError("The official template has an invalid output_path list.")
        output_literal = json.dumps(output_path, ensure_ascii=False)
    elif isinstance(output_path, str) and output_path.strip():
        output_literal = json.dumps(output_path, ensure_ascii=False)
    else:
        raise TemplateError("The official template's output_path is missing or unsupported.")

    display_name = str(catalog.get("name") or template_id)
    category = str(catalog.get("category") or "misc")
    manifest = (
        f"[catalog.{template_id}]\n"
        f"name = {json.dumps(display_name, ensure_ascii=False)}\n"
        f"category = {json.dumps(category, ensure_ascii=False)}\n\n"
        f"[templates.{template_id}]\n"
        f"input_path = {json.dumps(local_input.as_posix(), ensure_ascii=False)}\n"
        f"output_path = {output_literal}\n"
    )
    (destination / "template.toml").write_text(manifest, encoding="utf-8")


def download_github_folder(url: str, destination: Path) -> None:
    """Download only the selected GitHub directory through the Contents API, never a repo ZIP."""
    info = github_url_info(url)
    if not info:
        raise TemplateError(
            "Use a GitHub template-folder URL like https://github.com/OWNER/REPO/tree/main/APP, "
            "or a direct file URL. A repository root URL is ambiguous."
        )
    owner, repo, branch, mode_path = info
    if mode_path.startswith("blob:") or mode_path.startswith("raw:"):
        rel = mode_path.split(":", 1)[1]
        if mode_path.startswith("blob:"):
            raw_url = (
                f"https://raw.githubusercontent.com/{owner}/{repo}/"
                f"{urllib.parse.quote(branch, safe='')}/{urllib.parse.quote(rel, safe='/')}"
            )
        else:
            raw_url = url
        data = fetch_bytes(raw_url, MAX_SINGLE_FILE)
        filename = PurePosixPath(rel).name or "template.txt"
        destination.mkdir(parents=True, exist_ok=True)
        (destination / filename).write_bytes(data)
        return

    rel_folder = mode_path.split(":", 1)[1].strip("/")
    folder_parts = PurePosixPath(rel_folder).parts
    if not rel_folder or not folder_parts or ".." in folder_parts or PurePosixPath(rel_folder).is_absolute():
        raise TemplateError("Choose a specific safe template folder in the GitHub URL, not the repository root.")

    official_builtin = (
        owner.lower() == "noctalia-dev" and repo.lower() == "noctalia"
        and len(folder_parts) == 3 and folder_parts[:2] == ("assets", "templates")
    )
    api_repo = (
        f"https://api.github.com/repos/{urllib.parse.quote(owner, safe='')}/"
        f"{urllib.parse.quote(repo, safe='')}"
    )
    pending = [rel_folder]
    visited: set[str] = set()
    matched = 0
    scanned = 0
    total = 0
    destination.mkdir(parents=True, exist_ok=True)

    while pending:
        current = pending.pop()
        if current in visited:
            continue
        visited.add(current)
        api_url = (
            f"{api_repo}/contents/{urllib.parse.quote(current, safe='/')}"
            f"?ref={urllib.parse.quote(branch, safe='')}"
        )
        try:
            listing = json.loads(fetch_bytes(api_url, 4 * 1024 * 1024).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise TemplateError(f"GitHub returned an unreadable directory listing for '{current}'.") from exc
        if not isinstance(listing, list):
            raise TemplateError(
                f"'{current}' is not a GitHub folder. Paste the URL ending in /tree/BRANCH/FOLDER."
            )
        scanned += len(listing)
        if scanned > MAX_TOTAL_FILES * 4:
            raise TemplateError("The selected template folder contains too many files and subfolders.")

        for item in listing:
            if not isinstance(item, dict):
                continue
            item_type = item.get("type")
            api_path = item.get("path")
            if not isinstance(api_path, str):
                continue
            item_parts = PurePosixPath(api_path).parts
            if PurePosixPath(api_path).is_absolute() or ".." in item_parts:
                continue
            if item_parts[:len(folder_parts)] != folder_parts or len(item_parts) <= len(folder_parts):
                continue
            inner_parts = item_parts[len(folder_parts):]
            if any(part in {".git", "__pycache__", ".venv", "node_modules"} for part in item_parts):
                continue
            if item_type == "dir":
                pending.append(api_path)
                continue
            if item_type != "file":
                # Ignore symlinks, submodules and other non-regular entries.
                continue
            inner = PurePosixPath(*inner_parts)
            if inner.is_absolute() or ".." in inner.parts:
                continue
            # Noctalia's built-in apply/undo scripts are intentionally not copied;
            # Veyra never executes third-party shell hooks.
            if official_builtin and inner.name in {"apply.sh", "undo.sh"}:
                continue

            size = item.get("size", 0)
            if not isinstance(size, int) or size < 0:
                size = 0
            if size > MAX_SINGLE_FILE:
                raise TemplateError(f"Refusing large template file in GitHub folder: {inner} ({size} bytes).")
            if total + size > MAX_DOWNLOAD:
                raise TemplateError("GitHub template folder is larger than Veyra's download-size limit.")
            if matched + 1 > MAX_TOTAL_FILES:
                raise TemplateError("GitHub template folder contains too many files.")

            raw_url = (
                f"https://raw.githubusercontent.com/{owner}/{repo}/"
                f"{urllib.parse.quote(branch, safe='')}/{urllib.parse.quote(api_path, safe='/')}"
            )
            data = fetch_bytes(raw_url, MAX_SINGLE_FILE)
            if total + len(data) > MAX_DOWNLOAD:
                raise TemplateError("GitHub template folder is larger than Veyra's download-size limit.")
            target = destination / inner
            if not target.resolve(strict=False).is_relative_to(destination.resolve(strict=False)):
                raise TemplateError("A GitHub file path escaped the template folder; refusing to write it.")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            total += len(data)
            matched += 1

    if matched == 0:
        raise TemplateError(
            f"No regular files were found in GitHub folder '{rel_folder}'. "
            "Check the repository, branch and folder name."
        )

    # Noctalia's official built-ins use a shared assets/templates/builtin.toml catalog,
    # not the per-folder template.toml format used by community templates.
    create_official_builtin_manifest(owner, repo, branch, rel_folder, destination)


def local_path_from_source(source: str) -> Path:
    parsed = urllib.parse.urlparse(source)
    if parsed.scheme == "file":
        return Path(urllib.parse.unquote(parsed.path)).expanduser()
    if parsed.scheme and parsed.scheme not in {"http", "https"}:
        raise TemplateError(f"Unsupported source scheme: {parsed.scheme}")
    return Path(source).expanduser()


def is_manifest_folder(folder: Path) -> bool:
    return (folder / "template.toml").is_file()


def build_entries(source_dir: Path) -> tuple[str, list[dict[str, Any]]]:
    manifest_path = source_dir / "template.toml"
    if not manifest_path.is_file():
        raise TemplateError(
            "No template.toml was found. For a standalone file, set the destination path; "
            "for a Noctalia template, select its folder containing template.toml."
        )
    try:
        manifest = tomllib.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise TemplateError(f"Could not parse template.toml: {exc}") from exc

    catalogs = manifest.get("catalog", {})
    templates = manifest.get("templates", {})
    if not isinstance(templates, dict) or not templates:
        raise TemplateError("The manifest has no [templates.*] entries.")
    catalog_name = next(iter(catalogs), next(iter(templates))) if isinstance(catalogs, dict) else next(iter(templates))
    catalog = catalogs.get(catalog_name, {}) if isinstance(catalogs, dict) else {}
    display_name = str(catalog.get("name") or catalog_name)
    entries: list[dict[str, Any]] = []
    for entry_name, cfg in templates.items():
        if not isinstance(cfg, dict):
            continue
        if cfg.get("input_path_dynamic") or cfg.get("output_path_dynamic"):
            # Dynamic commands are intentionally never executed; omit that entry.
            continue
        input_path = cfg.get("input_path")
        input_modes = cfg.get("input_path_modes")
        output_path = cfg.get("output_path")
        if not input_path and not isinstance(input_modes, dict):
            continue
        if not output_path:
            continue
        rel_inputs: dict[str, str] = {}
        if isinstance(input_modes, dict):
            for mode in ("dark", "light"):
                val = input_modes.get(mode)
                if val:
                    rel_inputs[mode] = validate_source_relative(source_dir, str(val))
        elif input_path:
            rel_inputs["default"] = validate_source_relative(source_dir, str(input_path))
        if not rel_inputs:
            continue
        outputs = output_path if isinstance(output_path, list) else [output_path]
        outputs = [str(x) for x in outputs if isinstance(x, str) and x.strip()]
        if not outputs:
            continue
        entries.append({
            "name": str(entry_name),
            "input_paths": rel_inputs,
            "output_paths": outputs,
            "requires_path": str(cfg.get("requires_path")) if cfg.get("requires_path") else "",
            # Hooks, post actions and undo hooks are deliberately not retained.
        })
    if not entries:
        raise TemplateError(
            "No supported static entries were found. Veyra's first version supports input_path, "
            "input_path_modes, and output_path; command-based paths and shell hooks are not run."
        )
    return display_name, entries


def validate_source_relative(source_dir: Path, value: str) -> str:
    p = Path(value)
    if p.is_absolute():
        raise TemplateError(f"Template input path must be relative to its folder: {value}")
    resolved = (source_dir / p).resolve(strict=False)
    if not resolved.is_relative_to(source_dir.resolve()):
        raise TemplateError(f"Template input path escapes its folder: {value}")
    if not resolved.is_file():
        raise TemplateError(f"Template input file was not found: {value}")
    return resolved.relative_to(source_dir.resolve()).as_posix()


def import_source(source: str, output_path: str = "", name_override: str = "") -> str:
    USER_TEMPLATE_ROOT.mkdir(parents=True, exist_ok=True)
    if not source.strip():
        raise TemplateError("Enter a GitHub URL or local file/folder path.")

    with tempfile.TemporaryDirectory(prefix="veyra-template-stage-") as stage_name:
        stage = Path(stage_name)
        source_dir = stage / "source"
        origin = source
        remote_info = github_url_info(source) if source.startswith(("https://github.com/", "https://raw.githubusercontent.com/")) else None
        if remote_info:
            _, _, _, mode_path = remote_info
            if mode_path.startswith("blob:") or mode_path.startswith("raw:"):
                download_github_folder(source, source_dir)
            else:
                download_github_folder(source, source_dir)
        else:
            local = local_path_from_source(source)
            if not local.exists():
                raise TemplateError(f"Local source does not exist: {local}")
            if local.is_dir():
                safe_copy_tree(local, source_dir)
            elif local.is_file():
                if local.name == "template.toml":
                    safe_copy_tree(local.parent, source_dir)
                else:
                    source_dir.mkdir(parents=True, exist_ok=True)
                    if local.stat().st_size > MAX_SINGLE_FILE:
                        raise TemplateError("Selected template file is too large.")
                    shutil.copyfile(local, source_dir / local.name)
            else:
                raise TemplateError("Select a regular file or folder.")

        # A raw/direct file import becomes a simple template; manifest folders use Noctalia format.
        if (source_dir / "template.toml").is_file():
            display_name, entries = build_entries(source_dir)
            if name_override.strip():
                display_name = name_override.strip()
            base = name_override.strip() or display_name
            kind = "noctalia"
        else:
            files = [p for p in source_dir.rglob("*") if p.is_file() and not p.is_symlink()]
            if len(files) != 1:
                raise TemplateError("The selected source has no template.toml and is not a single file.")
            if not output_path.strip():
                raise TemplateError("For a standalone file, fill in its destination path before importing.")
            input_file = files[0]
            # Rename to a predictable path for the metadata.
            normal = source_dir / "template.input"
            if input_file != normal:
                shutil.move(str(input_file), str(normal))
            display_name = name_override.strip() or input_file.stem
            base = name_override.strip() or input_file.stem
            kind = "single-file"
            entries = [{
                "name": display_name,
                "input_paths": {"default": "template.input"},
                "output_paths": [output_path.strip()],
                "requires_path": "",
            }]

        template_id = unique_id(base)
        target = USER_TEMPLATE_ROOT / template_id
        target.mkdir(parents=True, exist_ok=False)
        try:
            shutil.copytree(source_dir, target / "source")
            metadata = {
                "id": template_id,
                "name": display_name,
                "origin": origin,
                "kind": kind,
                "entries": entries,
            }
            save_metadata(target, metadata)
        except Exception:
            shutil.rmtree(target, ignore_errors=True)
            raise
    return f"Imported '{display_name}' as {template_id}. It is disabled until you preview and enable it. Shell hooks were not imported or run."


def list_templates() -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for folder in iter_template_folders():
        meta = read_json(folder / "template.json")
        if not isinstance(meta, dict) or not isinstance(meta.get("id"), str):
            continue
        state = read_template_state(folder, meta)
        out_paths = []
        for entry in meta.get("entries", []):
            if isinstance(entry, dict):
                out_paths.extend(entry.get("output_paths", []))
        unique_paths = list(dict.fromkeys(out_paths))
        summary = f"{len(meta.get('entries', []))} render rule(s) · {len(unique_paths)} output path(s)"
        result.append({
            "id": meta["id"],
            "name": str(meta.get("name", meta["id"])),
            "enabled": bool(state.get("enabled", False)),
            "summary": summary,
        })
    return result


def template_folder(template_id: str) -> tuple[Path, dict[str, Any]]:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,80}", template_id):
        raise TemplateError("Invalid template ID.")
    migrate_legacy_user_templates()
    for root in template_roots():
        candidate = root / template_id
        if not candidate.exists():
            continue
        folder = candidate.resolve(strict=True)
        if not folder.is_relative_to(root.resolve(strict=False)):
            raise TemplateError("Invalid template path.")
        meta = read_json(folder / "template.json")
        if not isinstance(meta, dict):
            raise TemplateError(f"Template metadata is missing for {template_id}.")
        return folder, meta
    raise TemplateError(f"Template not found: {template_id}.")


def expand_path(raw: str, allow_directory: bool = False) -> Path:
    raw = raw.strip()
    xdg = {
        "$XDG_CONFIG_HOME": str(CONFIG_HOME),
        "${XDG_CONFIG_HOME}": str(CONFIG_HOME),
        "$XDG_DATA_HOME": str(DATA_HOME),
        "${XDG_DATA_HOME}": str(DATA_HOME),
        "$XDG_STATE_HOME": str(STATE_HOME),
        "${XDG_STATE_HOME}": str(STATE_HOME),
        "$XDG_CACHE_HOME": str(CACHE_HOME),
        "${XDG_CACHE_HOME}": str(CACHE_HOME),
    }
    for token, actual in xdg.items():
        if raw == token or raw.startswith(token + "/"):
            raw = actual + raw[len(token):]
            break
    raw = os.path.expanduser(os.path.expandvars(raw))
    path = Path(raw)
    if not path.is_absolute():
        path = CONFIG_HOME / "quickshell" / path
    resolved = path.resolve(strict=False)
    allowed_roots = (HOME, CONFIG_HOME, DATA_HOME, STATE_HOME, CACHE_HOME)
    if not any(resolved.is_relative_to(root) for root in allowed_roots):
        raise TemplateError(f"Output path must resolve inside your home directory: {raw}")
    # Refuse to follow a final symlink to an external or unexpected target.
    if path.is_symlink():
        raise TemplateError(f"Refusing to overwrite a symbolic link: {path}")
    if resolved == HOME or (resolved.is_dir() and not allow_directory):
        raise TemplateError(f"Output path must name a file, not a directory: {path}")
    return resolved


def _read_palette_file() -> Path | None:
    # Active palette lives in the state dir; fall back to the legacy cache copy.
    candidates = [
        STATE_HOME / "veyra/colorscheme.json",
        CACHE_HOME / "quickshell/colorscheme.json",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return candidates[0]


def current_palette() -> dict[str, Any]:
    file = _read_palette_file()
    data = read_json(file)
    if not isinstance(data, dict):
        raise TemplateError(f"Could not read palette JSON: {file}")
    # Mirror the palette construction in apply_theme.py so previews resemble actual output.
    try:
        from color_utils import blend_hex, get_brightness, resolve_color, sanitize_color
        bg = sanitize_color(data.get("bg", "#000000"))
        opaque_bg = sanitize_color(data.get("opaqueBg", bg))
        fg = sanitize_color(data.get("fg", "#ffffff"))
        accent = sanitize_color(data.get("accent", "#a77ef5"))
        complementary = sanitize_color(data.get("accentComplementary", "#f57eb6"))
        shadow = sanitize_color(data.get("shadow", "#000000"))
        dark = get_brightness(bg) <= 0.5
        fallback = blend_hex(accent, fg, 0.7 if dark else 1.0)
        overlay = resolve_color(data.get("overlayBase"), bg, fallback=fallback)
        colors = {
            "bg": bg, "opaqueBg": opaque_bg, "fg": fg, "overlayBase": overlay,
            "bgSecondary": resolve_color(data.get("bgSecondary"), bg, fallback=blend_hex(overlay, bg, 0.06 if dark else 0.10)),
            "bgTertiary": resolve_color(data.get("bgTertiary"), bg, fallback=blend_hex(overlay, bg, 0.02 if dark else 0.04)),
            "bgAccent": resolve_color(data.get("bgAccent"), bg, fallback=blend_hex(accent, bg, 0.15 if dark else 0.30)),
            "bgAccentComplementary": resolve_color(data.get("bgAccentComplementary"), bg, fallback=blend_hex(complementary, bg, 0.15 if dark else 0.30)),
            "muted": resolve_color(data.get("muted"), bg, fallback=blend_hex(fg, bg, 0.40)),
            "border": resolve_color(data.get("border"), bg, fallback=blend_hex(fg, bg, 0.10 if dark else 0.20)),
            "accent": accent, "accentComplementary": complementary, "shadow": shadow, "is_dark": dark,
        }
    except Exception:
        colors = dict(data)
        bg = str(colors.get("bg", "#000000"))
        colors["is_dark"] = colors.get("wallpaperIsDark", True)
    try:
        from matugen_palette import generate as generate_matugen_palette
        colors.update(generate_matugen_palette(str(colors.get("accent", "#a77ef5")), bool(colors.get("is_dark", True))))
    except Exception:
        pass
    return colors


def color_hex(value: Any) -> str:
    s = str(value).strip()
    if not s.startswith("#"):
        s = "#" + s
    raw = s[1:]
    if len(raw) == 8:  # Qt-style AARRGGBB in Veyra's translucent palette keys
        raw = raw[2:]
    if len(raw) == 3:
        raw = "".join(ch * 2 for ch in raw)
    if len(raw) != 6 or not re.fullmatch(r"[0-9a-fA-F]{6}", raw):
        raise TemplateError(f"Unsupported color value: {value}")
    return "#" + raw.lower()


def token_color(role: str, colors: dict[str, Any]) -> str:
    aliases = {
        "surface": ("surface", "bg"), "on_surface": ("on_surface", "fg"),
        "surface_variant": ("surface_variant", "bgSecondary"), "on_surface_variant": ("on_surface_variant", "muted"),
        "surface_dim": ("surface_dim", "bg"), "surface_bright": ("surface_bright", "bgSecondary"),
        "surface_container_lowest": ("surface_container_lowest", "bg"), "surface_container_low": ("surface_container_low", "bgSecondary"),
        "surface_container": ("surface_container", "bgSecondary"), "surface_container_high": ("surface_container_high", "bgTertiary"),
        "surface_container_highest": ("surface_container_highest", "bgTertiary"),
        "primary": ("primary", "accent"), "on_primary": ("on_primary", "fg"), "primary_container": ("primary_container", "bgAccent"), "on_primary_container": ("on_primary_container", "fg"),
        "secondary": ("secondary", "accentComplementary"), "on_secondary": ("on_secondary", "fg"), "secondary_container": ("secondary_container", "bgAccentComplementary"), "on_secondary_container": ("on_secondary_container", "fg"),
        "tertiary": ("tertiary", "overlayBase"), "on_tertiary": ("on_tertiary", "fg"), "tertiary_container": ("tertiary_container", "bgAccent"), "on_tertiary_container": ("on_tertiary_container", "fg"),
        "error": ("error", "accentComplementary"), "on_error": ("on_error", "fg"), "error_container": ("error_container", "bgAccentComplementary"), "on_error_container": ("on_error_container", "fg"),
        "outline": ("outline", "border"), "outline_variant": ("outline_variant", "border"), "shadow": ("shadow", "shadow"), "scrim": ("scrim", "shadow"),
        "background": ("background", "bg"), "on_background": ("on_background", "fg"), "hover": ("hover", "bgAccent"), "on_hover": ("on_hover", "fg"),
        "inverse_surface": ("inverse_surface", "fg"), "inverse_on_surface": ("inverse_on_surface", "bg"), "inverse_primary": ("inverse_primary", "accentComplementary"),
        "terminal_background": ("terminal_background", "bg"), "terminal_foreground": ("terminal_foreground", "fg"),
        # API-only folder downloader patch: map official Noctalia terminal tokens to Veyra colors.
        "terminal_normal_black": ("terminal_color0", "bg"),
        "terminal_normal_red": ("terminal_color1", "accentComplementary"),
        "terminal_normal_green": ("terminal_color2", "accent"),
        "terminal_normal_yellow": ("terminal_color3", "accentComplementary"),
        "terminal_normal_blue": ("terminal_color4", "accent"),
        "terminal_normal_magenta": ("terminal_color5", "accentComplementary"),
        "terminal_normal_cyan": ("terminal_color6", "accent"),
        "terminal_normal_white": ("terminal_color7", "overlayBase"),
        "terminal_bright_black": ("terminal_color8", "muted"),
        "terminal_bright_red": ("terminal_color9", "accentComplementary"),
        "terminal_bright_green": ("terminal_color10", "accent"),
        "terminal_bright_yellow": ("terminal_color11", "accentComplementary"),
        "terminal_bright_blue": ("terminal_color12", "accent"),
        "terminal_bright_magenta": ("terminal_color13", "accentComplementary"),
        "terminal_bright_cyan": ("terminal_color14", "accent"),
        "terminal_bright_white": ("terminal_color15", "fg"),
        "terminal_selection_fg": ("terminal_foreground", "fg"),
        "terminal_selection_bg": ("terminal_selection_bg", "bgAccent"),
        "terminal_cursor_text": ("fg", "on_primary"),
        "terminal_cursor": ("terminal_cursor", "accent"), "terminal_color0": ("terminal_color0", "bg"),
        "terminal_color1": ("terminal_color1", "error"), "terminal_color2": ("terminal_color2", "tertiary"),
        "terminal_color3": ("terminal_color3", "secondary"), "terminal_color4": ("terminal_color4", "primary"),
        "terminal_color5": ("terminal_color5", "tertiary"), "terminal_color6": ("terminal_color6", "secondary"),
        "terminal_color7": ("terminal_color7", "fg"), "terminal_color8": ("terminal_color8", "muted"),
        "terminal_color9": ("terminal_color9", "error"), "terminal_color10": ("terminal_color10", "tertiary"),
        "terminal_color11": ("terminal_color11", "secondary"), "terminal_color12": ("terminal_color12", "primary"),
        "terminal_color13": ("terminal_color13", "tertiary"), "terminal_color14": ("terminal_color14", "secondary"),
        "terminal_color15": ("terminal_color15", "fg"),
    }
    choices = aliases.get(role, (role, "accent"))
    for key in choices:
        for candidate in (key, "m3_" + key):
            if candidate in colors:
                try:
                    return color_hex(colors[candidate])
                except TemplateError:
                    continue
    return color_hex(colors.get("accent", "#a77ef5"))


def modify_color(value: str, filter_name: str, argument: str = "") -> str:
    base = color_hex(value)
    r, g, b = (int(base[i:i+2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if filter_name == "darken":
        l = max(0.0, l - float(argument) / 100)
    elif filter_name == "lighten":
        l = min(1.0, l + float(argument) / 100)
    elif filter_name == "saturate":
        s = min(1.0, s + float(argument) / 100)
    elif filter_name == "desaturate":
        s = max(0.0, s - float(argument) / 100)
    elif filter_name == "set_alpha":
        # Alpha is handled in rgba format. Preserve RGB here.
        return base
    elif filter_name == "invert":
        return "#" + "".join(f"{255 - int(base[i:i+2],16):02x}" for i in (1, 3, 5))
    elif filter_name == "grayscale":
        gray = round((0.2126 * r + 0.7152 * g + 0.0722 * b) * 255)
        return f"#{gray:02x}{gray:02x}{gray:02x}"
    elif filter_name in {"hex_stripped", "hex-stripped"}:
        return base[1:]
    else:
        raise TemplateError(f"Unsupported template filter: {filter_name}")
    nr, ng, nb = colorsys.hls_to_rgb(h, l, s)
    return "#%02x%02x%02x" % (round(nr * 255), round(ng * 255), round(nb * 255))


def format_color(base: str, fmt: str, colors: dict[str, Any], alpha: float = 1.0) -> str:
    base = color_hex(base)
    r, g, b = (int(base[i:i+2], 16) for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if fmt == "hex": return base
    if fmt == "hex_stripped": return base[1:]
    if fmt == "rgb": return f"rgb({r}, {g}, {b})"
    if fmt == "rgb_csv": return f"{r},{g},{b}"
    if fmt == "rgba": return f"rgba({r}, {g}, {b}, {alpha:g})"
    if fmt == "red": return str(r)
    if fmt == "green": return str(g)
    if fmt == "blue": return str(b)
    if fmt == "alpha": return f"{alpha:g}"
    if fmt == "hue": return str(round((h * 360) % 360))
    if fmt == "saturation": return str(round(s * 100))
    if fmt == "lightness": return str(round(l * 100))
    if fmt == "hsl": return f"hsl({round((h * 360) % 360)}, {round(s * 100)}%, {round(l * 100)}%)"
    if fmt == "hsla": return f"hsla({round((h * 360) % 360)}, {round(s * 100)}%, {round(l * 100)}%, {alpha:g})"
    raise TemplateError(f"Unsupported color format: {fmt}")


def evaluate_expression(expression: str, colors: dict[str, Any]) -> str:
    parts = [x.strip() for x in expression.split("|")]
    base_expr = parts[0]
    alpha = 1.0
    if base_expr == "mode":
        value: Any = "dark" if bool(colors.get("is_dark", True)) else "light"
        is_color = False
    elif base_expr == "image":
        value, is_color = "", False
    else:
        match = re.fullmatch(r"colors\.([a-zA-Z0-9_]+)\.(default|dark|light)\.([a-zA-Z0-9_]+)", base_expr)
        if not match:
            raise TemplateError(f"Unsupported template expression: {{{{ {expression} }}}}")
        role, _mode, fmt = match.groups()
        value = token_color(role, colors)
        is_color = True
        for filt in parts[1:]:
            m = re.fullmatch(r"([a-zA-Z_]+)(?:\s*\(\s*([-+]?[0-9]*\.?[0-9]+)\s*\)|\s*:?[ \t]+([-+]?[0-9]*\.?[0-9]+))?", filt)
            if not m:
                raise TemplateError(f"Unsupported template filter syntax: {filt}")
            fname, arg = m.group(1), m.group(2) or m.group(3) or ""
            if fname == "set_alpha":
                alpha = max(0.0, min(1.0, float(arg)))
            value = modify_color(str(value), fname, arg)
        return format_color(str(value), fmt, colors, alpha)
    if parts[1:]:
        for filt in parts[1:]:
            m = re.fullmatch(r"([a-zA-Z_]+)(?:\s*:?\s*(.*))?", filt)
            if not m:
                raise TemplateError(f"Unsupported template filter syntax: {filt}")
            fname, arg = m.group(1), (m.group(2) or "").strip().strip('"\'')
            if fname == "replace":
                vals = [x.strip().strip('"\'') for x in arg.split(",", 1)]
                if len(vals) != 2: raise TemplateError("replace filter needs two string arguments")
                value = str(value).replace(vals[0], vals[1])
            elif fname in {"lower_case", "snake_case", "kebab_case", "camel_case", "pascal_case"}:
                words = re.findall(r"[A-Za-z0-9]+", str(value))
                if fname == "lower_case": value = str(value).lower()
                elif fname == "snake_case": value = "_".join(w.lower() for w in words)
                elif fname == "kebab_case": value = "-".join(w.lower() for w in words)
                elif fname == "camel_case": value = (words[0].lower() + "".join(w.title() for w in words[1:])) if words else ""
                else: value = "".join(w.title() for w in words)
            else:
                raise TemplateError(f"Unsupported template filter: {fname}")
    return str(value)


def render_text(template_text: str, colors: dict[str, Any]) -> str:
    if re.search(r"<\*", template_text):
        raise TemplateError("This template uses Noctalia loop/conditional blocks, which Veyra's first version does not render yet.")
    result = EXPR_RE.sub(lambda m: evaluate_expression(m.group(1), colors), template_text)
    if "{{" in result or "}}" in result:
        raise TemplateError("Template contains unresolved placeholders; no output was written.")
    return result


def resolve_input(source_folder: Path, entry: dict[str, Any], colors: dict[str, Any]) -> Path:
    paths = entry.get("input_paths", {})
    mode = "dark" if bool(colors.get("is_dark", True)) else "light"
    rel = paths.get(mode) or paths.get("default") or paths.get("dark") or paths.get("light")
    if not rel:
        raise TemplateError(f"No input file configured for entry {entry.get('name', '?')}")
    candidate = (source_folder / rel).resolve(strict=True)
    if not candidate.is_relative_to(source_folder.resolve()) or not candidate.is_file():
        raise TemplateError(f"Unsafe or missing template input: {rel}")
    return candidate


def prepare_render(meta: dict[str, Any], folder: Path, colors: dict[str, Any]) -> list[tuple[Path, bytes]]:
    source_folder = folder / "source"
    rendered: list[tuple[Path, bytes]] = []
    for entry in meta.get("entries", []):
        if not isinstance(entry, dict):
            continue
        required = entry.get("requires_path", "")
        if required:
            try:
                requirement = expand_path(required, allow_directory=True)
            except TemplateError:
                requirement = Path(required).expanduser()
            if not requirement.exists():
                continue
        input_file = resolve_input(source_folder, entry, colors)
        rendered_text = render_text(input_file.read_text(encoding="utf-8"), colors)
        content = rendered_text.encode("utf-8")
        for raw_output in entry.get("output_paths", []):
            target = expand_path(str(raw_output))
            rendered.append((target, content))
    if not rendered:
        raise TemplateError("No output files were produced (check requires_path and manifest entries).")
    # A single template should not silently target the same file twice with different content.
    seen: dict[Path, bytes] = {}
    for path, content in rendered:
        if path in seen and seen[path] != content:
            raise TemplateError(f"Multiple entries render different content to the same output path: {path}")
        seen[path] = content
    return list(seen.items())


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def atomic_write(path: Path, data: bytes, *, durable: bool = True) -> None:
    """Atomically write generated files; skip identical content."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file():
        try:
            if path.read_bytes() == data:
                return
        except OSError:
            pass
    fd, tmp_name = tempfile.mkstemp(prefix=".veyra-template-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            # Template outputs are reproducible; skip the per-file fsync for
            # those outputs to avoid dozens of synchronous disk barriers per
            # wallpaper update. Metadata writes keep durable=True by default.
            if durable:
                os.fsync(stream.fileno())
        os.replace(tmp_name, path)
    except Exception:
        try: os.unlink(tmp_name)
        except OSError: pass
        raise


def apply_enabled(home: str, colors: dict[str, Any]) -> None:
    _bind_home(home)
    live_session = is_live_session(HOME)
    for folder in iter_template_folders():
        meta = read_json(folder / "template.json")
        if not isinstance(meta, dict):
            continue
        try:
            folder, meta = template_folder(str(meta.get("id", "")))
            state = read_template_state(folder, meta)
            if not state.get("enabled"):
                continue
            outputs = prepare_render(meta, folder, colors)
            backups = state.setdefault("backups", {})
            # Save each original once (or adopt an existing pre-Veyra .veyra-backup
            # if local state was cleared), recording it immediately.
            for target, _content in outputs:
                key = str(target)
                if target.exists() and key not in backups:
                    backup = target.with_name(target.name + ".veyra-backup")
                    if not backup.exists():
                        shutil.copy2(target, backup)
                    backups[key] = str(backup)
                    save_template_state(str(meta.get("id", folder.name)), state)
            updated_count = 0
            unchanged_count = 0
            changed_paths: set[Path] = set()
            metadata_changed = False
            stored_hashes = state.setdefault("last_hashes", {})
            for target, content in outputs:
                key = str(target)
                try:
                    identical = target.is_file() and target.read_bytes() == content
                except OSError:
                    identical = False
                if identical:
                    unchanged_count += 1
                else:
                    # These are generated app-theme files and can be rebuilt.
                    # Atomic rename still protects readers from partial content.
                    atomic_write(target, content, durable=False)
                    updated_count += 1
                    changed_paths.add(target.resolve())
                digest = sha256(content)
                if stored_hashes.get(key) != digest:
                    stored_hashes[key] = digest
                    metadata_changed = True
            if metadata_changed:
                save_template_state(str(meta.get("id", folder.name)), state)
            # VEYRA_FOOT_LIVE_COLORS_V2: push the freshly rendered palette to running Foot PTYs.
            foot_theme_path = (CONFIG_HOME / "foot/themes/noctalia").resolve()
            foot_theme_content = next(
                (content for target, content in outputs if target.resolve() == foot_theme_path),
                None,
            )
            foot_theme_changed = any(
                target.resolve() == foot_theme_path and target.resolve() in changed_paths
                for target, _content in outputs
            )
            if live_session and foot_theme_content is not None and foot_theme_changed:
                try:
                    import configparser
                    import os
                    import re
                    import subprocess

                    parser = configparser.ConfigParser(interpolation=None, strict=False)
                    parser.read_string(foot_theme_content.decode("utf-8"))
                    if not parser.has_section("colors-dark"):
                        raise ValueError("generated Foot theme has no [colors-dark] section")
                    foot_colors = parser["colors-dark"]

                    def foot_color(key: str) -> str:
                        raw = foot_colors.get(key, "").strip()
                        value = raw.split()[0].lstrip("#") if raw else ""
                        if not re.fullmatch(r"[0-9a-fA-F]{6}", value):
                            raise ValueError(f"invalid or missing Foot color {key}={raw!r}")
                        return "#" + value

                    # Foot supports OSC 4 (ANSI palette), 10/11 (default fg/bg),
                    # 12 (cursor), and 17/19 (selection colors).
                    sequences = [
                        f"\x1b]10;{foot_color('foreground')}\x1b\\",
                        f"\x1b]11;{foot_color('background')}\x1b\\",
                    ]
                    for color_index in range(16):
                        key = f"regular{color_index}" if color_index < 8 else f"bright{color_index - 8}"
                        sequences.append(f"\x1b]4;{color_index};{foot_color(key)}\x1b\\")

                    cursor_parts = foot_colors.get("cursor", "").split()
                    if len(cursor_parts) >= 2:
                        cursor_color = cursor_parts[1].lstrip("#")
                        if re.fullmatch(r"[0-9a-fA-F]{6}", cursor_color):
                            sequences.append(f"\x1b]12;#{cursor_color}\x1b\\")
                    sequences.extend([
                        f"\x1b]17;{foot_color('selection-background')}\x1b\\",
                        f"\x1b]19;{foot_color('selection-foreground')}\x1b\\",
                    ])
                    payload = "".join(sequences).encode("ascii")

                    # Map each Foot process to descendant shell TTYs. Writing OSC to the
                    # slave PTY sends it to that terminal emulator, without typing into
                    # the shell or restarting its session.
                    ps_result = subprocess.run(
                        ["ps", "-eo", "pid=,ppid=,comm=,tty="],
                        capture_output=True,
                        text=True,
                        timeout=3,
                        check=False,
                    )
                    if ps_result.returncode != 0:
                        raise RuntimeError("could not inspect running terminal processes")

                    processes = {}
                    children = {}
                    for line in ps_result.stdout.splitlines():
                        fields = line.split(maxsplit=3)
                        if len(fields) != 4:
                            continue
                        try:
                            pid, ppid = int(fields[0]), int(fields[1])
                        except ValueError:
                            continue
                        comm, tty = fields[2], fields[3].strip()
                        processes[pid] = (ppid, comm, tty)
                        children.setdefault(ppid, []).append(pid)

                    roots = [
                        pid for pid, (_ppid, comm, _tty) in processes.items()
                        if comm in ("foot", "footclient")
                    ]
                    live_ttys = set()
                    for root_pid in roots:
                        stack = [root_pid]
                        visited = set()
                        while stack:
                            pid = stack.pop()
                            if pid in visited:
                                continue
                            visited.add(pid)
                            record = processes.get(pid)
                            if record is None:
                                continue
                            _ppid, _comm, tty = record
                            if tty and tty not in ("?", "??", "-") and not tty.startswith("/"):
                                live_ttys.add(tty)
                            stack.extend(children.get(pid, []))

                    refreshed = []
                    failures = []
                    for tty in sorted(live_ttys):
                        device = Path("/dev") / tty
                        fd = None
                        try:
                            fd = os.open(
                                str(device),
                                os.O_WRONLY | getattr(os, "O_NOCTTY", 0) | getattr(os, "O_NONBLOCK", 0),
                            )
                            sent = 0
                            while sent < len(payload):
                                amount = os.write(fd, payload[sent:])
                                if amount <= 0:
                                    raise OSError("no bytes written to terminal")
                                sent += amount
                            refreshed.append(tty)
                        except OSError as exc:
                            failures.append(f"{device}: {exc}")
                        finally:
                            if fd is not None:
                                os.close(fd)

                    if refreshed:
                        emit(
                            "Veyra: live-updated Foot palette in "
                            f"{len(refreshed)} running terminal(s)."
                        )
                    elif failures:
                        emit(
                            "Veyra: wrote Foot's theme file, but live color push failed: "
                            + "; ".join(failures[:3]),
                            True,
                        )
                except Exception as exc:
                    emit(f"Veyra: could not live-update Foot colors: {exc}", True)
            emit(
                f"Veyra custom template '{meta.get('name', meta.get('id'))}': "
                f"updated {updated_count} output file(s); {unchanged_count} unchanged."
            )
        except Exception as exc:
            emit(f"Veyra custom template '{meta.get('name', folder.name)}' skipped: {exc}", True)


def preview(template_id: str) -> str:
    folder, meta = template_folder(template_id)
    colors = current_palette()
    outputs = prepare_render(meta, folder, colors)
    lines = [f"Preview: {meta.get('name', template_id)}", "No files will be written."]
    for path, content in outputs:
        text = content.decode("utf-8", errors="replace")
        lines.append(f"\n→ {path}")
        excerpt = "\n".join(text.splitlines()[:6])
        if len(excerpt) > 700: excerpt = excerpt[:700] + "…"
        lines.append(excerpt if excerpt else "(empty output)")
    lines.append("\nShell hooks are ignored. Preview does not modify app files.")
    return "\n".join(lines)


def set_enabled(template_id: str, value: bool) -> str:
    folder, meta = template_folder(template_id)
    state = read_template_state(folder, meta)
    state["enabled"] = value
    save_template_state(template_id, state)
    return f"{meta.get('name', template_id)}: automatic palette updates {'enabled' if value else 'disabled'}. Disabling leaves the last generated files in place."


def remove_template(template_id: str) -> str:
    folder, meta = template_folder(template_id)
    # Bundled templates are part of the project checkout. Users can disable
    # them, but deleting them through the UI would modify the shared install.
    try:
        is_bundled = folder.is_relative_to(BUNDLED_TEMPLATE_ROOT.resolve())
    except OSError:
        is_bundled = False
    if is_bundled:
        raise TemplateError("Bundled templates cannot be removed. Disable the template instead.")
    state = read_template_state(folder, meta)
    if state.get("enabled"):
        raise TemplateError("Disable this template before removing it.")
    notes: list[str] = []
    colors_hashes = state.get("last_hashes", {})
    backups = state.get("backups", {})
    # Restore only when the output still matches the last rendered version; preserve user edits.
    for raw_path, last_hash in colors_hashes.items():
        path = Path(raw_path)
        if not path.exists() or not path.is_file():
            continue
        try:
            if sha256(path.read_bytes()) != last_hash:
                notes.append(f"Left modified output untouched: {path}")
                continue
            backup_name = backups.get(raw_path)
            if backup_name and Path(backup_name).is_file():
                shutil.copy2(backup_name, path)
                Path(backup_name).unlink(missing_ok=True)
                notes.append(f"Restored backup: {path}")
            else:
                path.unlink()
                notes.append(f"Removed generated file: {path}")
        except OSError as exc:
            notes.append(f"Could not clean {path}: {exc}")
    shutil.rmtree(folder)
    try:
        template_state_path(template_id).unlink(missing_ok=True)
    except OSError:
        pass
    suffix = "\n" + "\n".join(notes) if notes else ""
    return f"Removed custom template '{meta.get('name', template_id)}'." + suffix


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list", help="list imported templates as JSON")
    imp = sub.add_parser("import", help="import a Noctalia template folder or standalone file")
    imp.add_argument("--source", required=True)
    imp.add_argument("--name", default="")
    imp.add_argument("--output-path", default="")
    en = sub.add_parser("set-enabled", help="enable or disable automatic updates")
    en.add_argument("template_id")
    en.add_argument("enabled", choices=("true", "false"))
    prev = sub.add_parser("preview", help="render a preview without writing any output")
    prev.add_argument("template_id")
    rem = sub.add_parser("remove", help="remove template and safely restore generated outputs")
    rem.add_argument("template_id")
    args = parser.parse_args()
    try:
        if args.command == "list":
            print(json.dumps(list_templates(), ensure_ascii=False), flush=True)
        elif args.command == "import":
            emit(import_source(args.source, args.output_path, args.name))
        elif args.command == "set-enabled":
            emit(set_enabled(args.template_id, args.enabled == "true"))
        elif args.command == "preview":
            emit(preview(args.template_id))
        elif args.command == "remove":
            emit(remove_template(args.template_id))
        return 0
    except (TemplateError, OSError, ValueError) as exc:
        emit(f"Error: {exc}", True)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
