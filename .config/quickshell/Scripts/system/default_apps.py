#!/usr/bin/env python3
"""Veyra Default Apps helper: discover desktop entries, set MIME defaults, launch choices."""
from __future__ import annotations

import configparser
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME") or (HOME / ".local/state")).expanduser()
PREFS_PATH = STATE_HOME / "veyra/settings_prefs.json"

ROLE_SETTINGS = {
    "browser": "defaultBrowserAppId",
    "coding": "defaultCodingAppId",
    "fileManager": "defaultFileManagerAppId",
    "textEditor": "defaultTextEditorAppId",
    "imageViewer": "defaultImageViewerAppId",
    "videoPlayer": "defaultVideoPlayerAppId",
    "musicPlayer": "defaultMusicPlayerAppId",
    "pdfViewer": "defaultPdfViewerAppId",
}

ROLE_MIMES = {
    "browser": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"],
    "fileManager": ["inode/directory"],
    "textEditor": ["text/plain"],
    "imageViewer": ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/tiff"],
    "videoPlayer": ["video/mp4", "video/webm", "video/x-matroska", "video/quicktime", "video/mpeg", "video/ogg"],
    "musicPlayer": ["audio/mpeg", "audio/ogg", "audio/flac", "audio/wav", "audio/mp4", "audio/aac", "audio/x-vorbis+ogg"],
    "pdfViewer": ["application/pdf"],
}

TERMINALS = {
    "kitty": ("Kitty", ["-e"]),
    "foot": ("foot", ["-e"]),
    "alacritty": ("Alacritty", ["-e"]),
    "konsole": ("Konsole", ["-e"]),
    "ghostty": ("Ghostty", ["-e"]),
    "wezterm": ("WezTerm", ["start", "--"]),
    "gnome-terminal": ("GNOME Terminal", ["--"]),
    "xfce4-terminal": ("Xfce Terminal", ["--command"]),
    "xterm": ("XTerm", ["-e"]),
    "kgx": ("GNOME Console", ["--"]),
    "tilix": ("Tilix", ["-e"]),
    "terminator": ("Terminator", ["-x"]),
}


def read_preferences() -> dict:
    try:
        data = json.loads(PREFS_PATH.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def desktop_dirs() -> list[Path]:
    dirs: list[Path] = []
    xdg_home = Path(os.environ.get("XDG_DATA_HOME") or (HOME / ".local/share"))
    dirs.append(xdg_home / "applications")
    dirs.extend([
        HOME / ".local/share/flatpak/exports/share/applications",
        Path("/var/lib/flatpak/exports/share/applications"),
        Path("/var/lib/snapd/desktop/applications"),
        Path("/usr/local/share/applications"),
    ])
    xdg_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for base in xdg_dirs.split(":"):
        if base:
            dirs.append(Path(base) / "applications")
    dirs.append(Path("/usr/share/applications"))

    unique: list[Path] = []
    seen: set[str] = set()
    for path in dirs:
        key = str(path)
        if key not in seen:
            seen.add(key)
            unique.append(path)
    return unique


def exec_program(exec_line: str) -> str:
    if not exec_line:
        return ""
    try:
        parts = shlex.split(exec_line, posix=True)
    except ValueError:
        return ""
    while parts and (parts[0] == "env" or ("=" in parts[0] and not parts[0].startswith("/"))):
        parts.pop(0)
    if not parts:
        return ""
    return Path(parts[0]).name


def read_desktop(path: Path) -> dict | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        with path.open("r", encoding="utf-8", errors="replace") as stream:
            parser.read_file(stream)
        entry = parser["Desktop Entry"]
    except (OSError, KeyError, configparser.Error):
        return None

    if entry.get("Type", "Application") != "Application":
        return None
    if entry.get("Hidden", "false").lower() == "true" or entry.get("NoDisplay", "false").lower() == "true":
        return None

    name = entry.get("Name", path.stem).strip() or path.stem
    exec_line = entry.get("Exec", "").strip()
    if not exec_line:
        return None
    categories = [item for item in entry.get("Categories", "").split(";") if item]
    mime_types = [item for item in entry.get("MimeType", "").split(";") if item]
    return {
        "id": path.name,
        "name": name,
        "exec": exec_line,
        "program": exec_program(exec_line),
        "categories": categories,
        "mimeTypes": mime_types,
    }


def collect_apps() -> list[dict]:
    by_id: dict[str, dict] = {}
    for directory in desktop_dirs():
        if not directory.is_dir():
            continue
        try:
            paths = sorted(directory.glob("*.desktop"), key=lambda p: p.name.lower())
        except OSError:
            continue
        for path in paths:
            if path.name in by_id:
                continue
            record = read_desktop(path)
            if record:
                by_id[path.name] = record
    return sorted(by_id.values(), key=lambda row: row["name"].casefold())


def query_default(mime: str) -> str:
    if not shutil.which("xdg-mime"):
        return ""
    try:
        result = subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True, text=True, timeout=2)
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def defaults_for_roles() -> dict[str, str]:
    probe = {
        "browser": "x-scheme-handler/https",
        "fileManager": "inode/directory",
        "textEditor": "text/plain",
        "imageViewer": "image/png",
        "videoPlayer": "video/mp4",
        "musicPlayer": "audio/mpeg",
        "pdfViewer": "application/pdf",
    }
    return {role: query_default(mime) for role, mime in probe.items()}


def role_choices(apps: list[dict]) -> dict[str, list[str]]:
    """Return role-specific apps using desktop semantics, not broad file support."""
    import re

    def categories(app):
        return {str(value) for value in (app.get("categories") or [])}

    def searchable_name(app):
        # Do not inspect Exec: wrapper flags can contain words such as "chromium"
        # even when the application itself is not a browser.
        return " ".join(
            str(app.get(key) or "")
            for key in ("name", "id")
        ).casefold()

    def name_has(app, phrases):
        normalized = re.sub(r"[^a-z0-9]+", " ", searchable_name(app)).strip()
        padded = f" {normalized} "
        for phrase in phrases:
            wanted = re.sub(r"[^a-z0-9]+", " ", phrase.casefold()).strip()
            if wanted and f" {wanted} " in padded:
                return True
        return False

    def mime_types(app):
        return [str(value).casefold() for value in (app.get("mimeTypes") or [])]

    def has_mime_prefix(app, prefix):
        prefix = prefix.casefold()
        return any(value.startswith(prefix) for value in mime_types(app))

    def has_mime(app, mime):
        return mime.casefold() in mime_types(app)

    def is_web_app(app):
        app_id = str(app.get("id") or "").casefold()
        return ".webapp-" in app_id or "WebApp" in categories(app)

    browser_names = (
        "firefox", "chromium", "google chrome", "chrome",
        "zen browser", "brave", "vivaldi", "opera",
        "microsoft edge", "librewolf", "floorp", "waterfox",
    )
    coding_names = (
        "vscodium", "visual studio code", "code oss", "zed",
        "intellij idea", "pycharm", "webstorm", "rider", "clion",
        "eclipse", "qt creator", "geany",
    )
    file_manager_names = (
        "dolphin", "thunar", "nautilus", "nemo", "pcmanfm",
        "yazi", "caja", "krusader", "double commander", "spacefm",
        "pantheon files", "cosmic files",
    )
    text_editor_names = (
        "micro", "kate", "kwrite", "mousepad", "gedit", "xed",
        "leafpad", "vim", "neovim", "emacs", "helix",
        "notepadqq", "sublime text",
    )
    image_viewer_names = (
        "gwenview", "qview", "imv", "feh", "ristretto", "loupe",
        "eye of gnome", "eog", "sxiv", "nsxiv", "nomacs",
        "viewnior", "geeqie", "mirage",
    )
    video_player_names = (
        "vlc", "mpv", "haruna", "celluloid", "smplayer",
        "parole", "totem", "mplayer", "clapper",
    )
    music_player_names = (
        "spotify", "strawberry", "audacious", "rhythmbox",
        "deadbeef", "clementine", "elisa", "amarok", "lollypop",
        "quodlibet", "sayonara", "cmus", "musikcube", "vlc", "mpv",
    )
    pdf_viewer_names = (
        "okular", "evince", "zathura", "atril", "sioyek",
        "mupdf", "foxit reader",
    )

    def is_browser(app):
        cats = categories(app)
        if is_web_app(app):
            return False
        return (
            "WebBrowser" in cats
            or has_mime(app, "x-scheme-handler/http")
            or has_mime(app, "x-scheme-handler/https")
            or name_has(app, browser_names)
        )

    def is_coding_app(app):
        cats = categories(app)
        excluded = {
            "TextEditor", "Documentation", "Network",
            "AudioVideo", "AudioVideoEditing", "Graphics", "Office",
        }
        return (
            "IDE" in cats
            or ("Development" in cats and not (cats & excluded))
            or name_has(app, coding_names)
        )

    def is_file_manager(app):
        return "FileManager" in categories(app) or name_has(app, file_manager_names)

    def is_text_editor(app):
        return "TextEditor" in categories(app) or name_has(app, text_editor_names)

    def is_image_viewer(app):
        cats = categories(app)
        return (
            ("Viewer" in cats and has_mime_prefix(app, "image/"))
            or name_has(app, image_viewer_names)
        )

    def is_video_player(app):
        cats = categories(app)
        audio_only = "Audio" in cats and "Video" not in cats
        return (
            "Player" in cats
            and has_mime_prefix(app, "video/")
            and not audio_only
        ) or name_has(app, video_player_names)

    def is_music_player(app):
        cats = categories(app)
        return (
            (
                "Player" in cats
                and "Audio" in cats
                and has_mime_prefix(app, "audio/")
            )
            or name_has(app, music_player_names)
        )

    def is_pdf_viewer(app):
        cats = categories(app)
        return (
            ("Viewer" in cats and has_mime(app, "application/pdf"))
            or name_has(app, pdf_viewer_names)
        )

    predicates = {
        "browser": is_browser,
        "coding": is_coding_app,
        "fileManager": is_file_manager,
        "textEditor": is_text_editor,
        "imageViewer": is_image_viewer,
        "videoPlayer": is_video_player,
        "musicPlayer": is_music_player,
        "pdfViewer": is_pdf_viewer,
    }
    return {
        role: [app["id"] for app in apps if predicate(app)]
        for role, predicate in predicates.items()
    }

def terminal_choices(apps: list[dict]) -> list[dict]:
    # Use the canonical terminal name, not an application launched inside it.
    result = []
    for command, (friendly, _flags) in TERMINALS.items():
        if shutil.which(command):
            result.append({"command": command, "name": friendly})
    return result


def list_apps() -> int:
    apps = collect_apps()
    result = {
        "apps": apps,
        "choices": role_choices(apps),
        "defaults": defaults_for_roles(),
        "terminals": terminal_choices(apps),
    }
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


def uwsm_command(command: list[str]) -> list[str]:
    if shutil.which("uwsm"):
        return ["uwsm", "app", "--", *command]
    return command


def spawn(command: list[str]) -> int:
    if not command or not shutil.which(command[0]):
        print(f"Cannot launch command: {command[0] if command else '(empty command)'}", file=sys.stderr)
        return 127
    try:
        subprocess.Popen(uwsm_command(command), start_new_session=True, close_fds=True)
        return 0
    except OSError as exc:
        print(f"Launch failed: {exc}", file=sys.stderr)
        return 1


def selected_app_id(role: str, prefs: dict, apps: list[dict]) -> str:
    setting = ROLE_SETTINGS.get(role, "")
    chosen = str(prefs.get(setting, "") or "").strip() if setting else ""
    all_ids = {a["id"] for a in apps}
    if chosen in all_ids:
        return chosen

    defaults = defaults_for_roles()
    current = defaults.get(role, "")
    if current in all_ids:
        return current

    choices = role_choices(apps).get(role, [])
    if role == "coding" and "codium.desktop" in all_ids:
        return "codium.desktop"
    return choices[0] if choices else ""


def launch_desktop_id(desktop_id: str) -> int:
    if not desktop_id:
        print("No compatible desktop application was found. Choose one in Veyra Settings → Default Apps.", file=sys.stderr)
        return 2
    if not shutil.which("gtk-launch"):
        print("gtk-launch is unavailable; install GTK's gtk-launch utility.", file=sys.stderr)
        return 127
    app_name = desktop_id[:-8] if desktop_id.endswith(".desktop") else desktop_id
    return spawn(["gtk-launch", app_name])


def terminal_command(prefs: dict) -> str:
    command = str(prefs.get("defaultTerminalCommand", "kitty") or "kitty").strip()
    if command in TERMINALS and shutil.which(command):
        return command
    for candidate in TERMINALS:
        if shutil.which(candidate):
            return candidate
    return ""


def wrap_in_terminal(command: list[str], prefs: dict, floating: bool = False) -> int:
    terminal = terminal_command(prefs)
    if not terminal:
        print("No supported terminal was found. Install a terminal emulator or choose one in Veyra Settings.", file=sys.stderr)
        return 127
    if floating and terminal == "kitty":
        return spawn([terminal, "--class", "kitty-floating"])
    if not command:
        return spawn([terminal])

    if terminal == "xfce4-terminal":
        return spawn([terminal, "--command", shlex.join(command)])
    if terminal == "gnome-terminal":
        return spawn([terminal, "--", *command])
    if terminal == "kgx":
        return spawn([terminal, "--", *command])
    if terminal == "wezterm":
        return spawn([terminal, "start", "--", *command])
    flags = TERMINALS.get(terminal, ("", ["-e"]))[1]
    return spawn([terminal, *flags, *command])


def set_default(role: str, desktop_id: str) -> int:
    if role not in ROLE_MIMES:
        print(f"Unsupported system-default role: {role}", file=sys.stderr)
        return 2
    if not any(app["id"] == desktop_id for app in collect_apps()):
        print(f"Desktop app is not installed or available: {desktop_id}", file=sys.stderr)
        return 2
    if not shutil.which("xdg-mime"):
        print("xdg-mime is not installed.", file=sys.stderr)
        return 127

    failed = []
    for mime in ROLE_MIMES[role]:
        try:
            result = subprocess.run(["xdg-mime", "default", desktop_id, mime], capture_output=True, text=True, timeout=5)
            if result.returncode != 0:
                failed.append(mime)
        except (OSError, subprocess.SubprocessError):
            failed.append(mime)
    if failed:
        print("Could not set these MIME defaults: " + ", ".join(failed), file=sys.stderr)
        return 1
    print(f"Updated {role} default to {desktop_id}")
    return 0


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print("Usage: default_apps.py list | set-default ROLE APP.desktop | launch ROLE | run-in-terminal ARGV... | run-shell-in-terminal COMMAND")
        return 0 if argv else 2

    action = argv[0]
    if action == "list":
        return list_apps()
    if action == "set-default" and len(argv) == 3:
        return set_default(argv[1], argv[2])

    prefs = read_preferences()
    if action == "run-in-terminal":
        return wrap_in_terminal(argv[1:], prefs)
    if action == "run-shell-in-terminal" and len(argv) >= 2:
        return wrap_in_terminal(["sh", "-lc", argv[1]], prefs)
    if action == "run-shell" and len(argv) >= 2:
        return spawn(["sh", "-lc", argv[1]])
    if action == "launch" and len(argv) == 2:
        role = argv[1]
        if role == "terminal":
            return wrap_in_terminal([], prefs)
        if role == "terminal-floating":
            return wrap_in_terminal([], prefs, floating=True)
        if role == "btop":
            return wrap_in_terminal(["btop"], prefs)
        if role not in ROLE_SETTINGS:
            print(f"Unsupported launch role: {role}", file=sys.stderr)
            return 2
        apps = collect_apps()
        selected = selected_app_id(role, prefs, apps)
        return launch_desktop_id(selected)

    print("Invalid arguments. Run default_apps.py --help for usage.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
