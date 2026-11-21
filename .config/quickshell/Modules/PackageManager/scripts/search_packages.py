#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import re
import shutil
import subprocess

os.environ["LC_ALL"] = "C"

# AUR helper: paru preferred, then yay. If neither exists we fall back to plain pacman (repo packages only).
AUR_HELPER = shutil.which("paru") or shutil.which("yay")
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
# yay prints "(Installed)", paru/pacman print "[Installed]" / "[installed: 1.0-1]"
INSTALLED_RE = re.compile(r"[\[(]installed(?::[^\])]*)?[\])]", re.IGNORECASE)


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


REPOSITORY_PRIORITY = {
    "core": 0,
    "extra": 1,
    "multilib": 2,
    "community": 3,
    "aur": 50,
}


def installed_foreign_names() -> set[str]:
    """Return package names installed outside the configured sync repositories."""
    try:
        result = subprocess.run(
            ["pacman", "-Qm"], capture_output=True, text=True, timeout=10
        )
        return {line.split()[0] for line in result.stdout.splitlines() if line.split()}
    except (OSError, subprocess.TimeoutExpired):
        return set()


def package_rank(pkg: dict, foreign_installed: set[str] | None = None) -> tuple:
    name = str(pkg.get("name", "")).lower()
    repo = str(pkg.get("repo", "")).lower()
    is_aur = str(pkg.get("source", "")).lower() == "aur" or repo == "aur"
    installed = bool(pkg.get("installed"))

    # If pacman identifies the installed package as foreign, prefer its AUR
    # metadata even when the sync-repository search result also carries an
    # installed marker (pacman marks by package name, not origin).
    if foreign_installed and name in foreign_installed:
        source_rank = 0 if is_aur else 1
    else:
        source_rank = 0 if not is_aur else 1

    repo_rank = REPOSITORY_PRIORITY.get(repo, 10 if not is_aur else 50)
    return (source_rank, 0 if installed else 1, repo_rank)


def deduplicate_packages(packages: list[dict], foreign_installed: set[str] | None = None) -> list[dict]:
    """Keep one useful result per package name, preserving first-seen order."""
    chosen: dict[str, dict] = {}
    order: list[str] = []
    for pkg in packages:
        name = str(pkg.get("name", "")).strip()
        if not name:
            continue
        key = name.casefold()
        if key not in chosen:
            chosen[key] = pkg
            order.append(key)
            continue
        if package_rank(pkg, foreign_installed) < package_rank(chosen[key], foreign_installed):
            chosen[key] = pkg
    return [chosen[key] for key in order]


def flush_sync_info(current_pkg: dict, packages: list[dict], installed_set: set[str]) -> None:
    name = current_pkg.get("name", "").strip()
    if not name:
        return
    repo = current_pkg.get("repo", "") or "unknown"
    packages.append(
        {
            "name": name,
            "version": current_pkg.get("version", ""),
            "repo": repo,
            "source": "AUR" if repo.lower() == "aur" else "pacman",
            "description": current_pkg.get("description", ""),
            "installed": name in installed_set,
        }
    )


def get_installed_packages() -> list[dict]:
    try:
        all_info_proc = subprocess.run(
            ["pacman", "-Qi"], capture_output=True, text=True
        )
        if all_info_proc.returncode != 0:
            return []

        foreign_pkg_proc = subprocess.run(
            ["pacman", "-Qm"], capture_output=True, text=True
        )
        foreign_names = {
            line.split()[0]
            for line in foreign_pkg_proc.stdout.strip().split("\n")
            if line
        }

        sync_pkg_proc = subprocess.run(
            ["pacman", "-Sl"], capture_output=True, text=True
        )
        repo_map = {}
        for line in sync_pkg_proc.stdout.strip().split("\n"):
            parts = line.split()
            if len(parts) >= 2:
                repo_map[parts[1]] = parts[0]

        packages = []
        current_pkg = {}

        for line in all_info_proc.stdout.split("\n"):
            if not line.strip():
                if current_pkg.get("name"):
                    name = current_pkg["name"]
                    is_aur = name in foreign_names
                    packages.append(
                        {
                            "name": name,
                            "version": current_pkg.get("version", ""),
                            "repo": "aur" if is_aur else repo_map.get(name, "pacman"),
                            "source": "AUR" if is_aur else "pacman",
                            "description": current_pkg.get("description", ""),
                            "installed": True,
                            "is_full_list": True,
                        }
                    )
                current_pkg = {}
                continue

            if " : " in line:
                key, val = line.split(" : ", 1)
                key = key.strip()
                val = val.strip()
                if key == "Name":
                    current_pkg["name"] = val
                elif key == "Version":
                    current_pkg["version"] = val
                elif key == "Description":
                    current_pkg["description"] = val

        if current_pkg.get("name"):
            name = current_pkg["name"]
            is_aur = name in foreign_names
            packages.append(
                {
                    "name": name,
                    "version": current_pkg.get("version", ""),
                    "repo": "aur" if is_aur else repo_map.get(name, "pacman"),
                    "source": "AUR" if is_aur else "pacman",
                    "description": current_pkg.get("description", ""),
                    "installed": True,
                    "is_full_list": True,
                }
            )

        packages = deduplicate_packages(packages, foreign_names)
        return sorted(packages, key=lambda x: x["name"].lower())
    except Exception:
        return []


def search_packages(query: str) -> list[dict]:
    if not query or len(query) < 2:
        return []

    try:
        result = subprocess.run(
            [AUR_HELPER or "pacman", "-Ss", query],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode not in (0, 1):
            return []

        header_re = re.compile(r"^(?P<repo>[^/\s]+)/(?P<name>\S+)\s+(?P<rest>.*)$")
        packages = []
        lines = strip_ansi(result.stdout).splitlines()
        for index, raw_line in enumerate(lines):
            header = raw_line.strip()
            match = header_re.match(header)
            if not match:
                continue

            repo = match.group("repo")
            name = match.group("name")
            rest = match.group("rest").strip()
            version = rest.split()[0] if rest else ""
            description = ""
            for next_line in lines[index + 1:]:
                candidate = next_line.strip()
                if not candidate:
                    break
                if header_re.match(candidate):
                    break
                description = candidate
                break

            packages.append(
                {
                    "name": name,
                    "version": version,
                    "repo": repo,
                    "source": "AUR" if repo.lower() == "aur" else "pacman",
                    "description": description,
                    "installed": bool(INSTALLED_RE.search(header)),
                }
            )

        foreign_names = installed_foreign_names()
        packages = deduplicate_packages(packages, foreign_names)
        query_lower = query.lower()

        def sort_key(pkg):
            name_lower = pkg["name"].lower()
            if name_lower == query_lower:
                tier = 0
            elif name_lower.startswith(query_lower):
                tier = 1
            elif re.search(r"(^|[-_])" + re.escape(query_lower), name_lower):
                tier = 2
            elif query_lower in name_lower:
                tier = 3
            else:
                tier = 4
            return (tier, *package_rank(pkg, foreign_names), len(name_lower))

        packages.sort(key=sort_key)
        return packages[:50]
    except (OSError, subprocess.TimeoutExpired):
        return []


def get_updates() -> list[dict]:
    packages = []
    try:
        res = subprocess.run(["checkupdates"], capture_output=True, text=True)
        if res.stdout:
            for line in res.stdout.strip().split("\n"):
                if not line:
                    continue
                parts = line.split()
                if len(parts) >= 4 and parts[2] == "->":
                    pkgname = parts[0]
                    old_ver = parts[1]
                    new_ver = parts[3]
                    packages.append(
                        {
                            "name": pkgname,
                            "version": f"{old_ver} -> {new_ver}",
                            "repo": "pacman",
                            "source": "pacman",
                            "description": "",
                            "installed": True,
                        }
                    )
    except Exception:
        pass

    try:
        if not AUR_HELPER:
            raise FileNotFoundError("no AUR helper installed")
        res = subprocess.run([AUR_HELPER, "-Qua"], capture_output=True, text=True)
        aur_out = strip_ansi(res.stdout)
        if aur_out:
            for line in aur_out.strip().split("\n"):
                if not line:
                    continue
                parts = line.split()
                if len(parts) >= 4 and parts[2] == "->":
                    pkgname = parts[0]
                    old_ver = parts[1]
                    new_ver = parts[3]
                    packages.append(
                        {
                            "name": pkgname,
                            "version": f"{old_ver} -> {new_ver}",
                            "repo": "aur",
                            "source": "AUR",
                            "description": "",
                            "installed": True,
                        }
                    )
    except Exception:
        pass

    seen = set()
    deduped_packages = []
    for p in packages:
        if p["name"] not in seen:
            seen.add(p["name"])
            deduped_packages.append(p)
    packages = deduped_packages

    if packages:
        try:
            pkg_names = [p["name"] for p in packages]
            info_proc = subprocess.run(
                ["pacman", "-Qi"] + pkg_names, capture_output=True, text=True
            )
            desc_map = {}
            current_name = None
            if info_proc.stdout:
                for line in info_proc.stdout.split("\n"):
                    if " : " in line:
                        k, v = line.split(" : ", 1)
                        k, v = k.strip(), v.strip()
                        if k == "Name":
                            current_name = v
                        elif k == "Description" and current_name:
                            desc_map[current_name] = v
            for p in packages:
                p["description"] = desc_map.get(
                    p["name"], f"Update available: {p['version']}"
                )
        except Exception:
            for p in packages:
                p["description"] = f"Update available: {p['version']}"

    return sorted(packages, key=lambda x: x["name"].lower())


def get_featured_packages(category_id: str = "featured") -> list[dict]:
    try:
        script_dir = os.path.dirname(os.path.realpath(__file__))
        json_path = os.path.join(script_dir, "featured_packages.json")
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        packages_dict = data.get("packages", {})
        if category_id == "all":
            popular_names = []
            for names in packages_dict.values():
                popular_names.extend(names)
            popular_names = list(dict.fromkeys(popular_names))
        else:
            popular_names = list(
                dict.fromkeys(packages_dict.get(category_id, packages_dict.get("featured", [])))
            )
        if not popular_names:
            return []
    except (OSError, ValueError, TypeError):
        return []

    try:
        installed_proc = subprocess.run(
            ["pacman", "-Qq"], capture_output=True, text=True, timeout=10
        )
        installed_set = set(installed_proc.stdout.split())
        foreign_names = installed_foreign_names()

        result = subprocess.run(
            [AUR_HELPER or "pacman", "-Si"] + popular_names,
            capture_output=True,
            text=True,
            timeout=20,
        )

        packages = []
        current_pkg = {}
        for line in strip_ansi(result.stdout).splitlines():
            if not line.strip():
                flush_sync_info(current_pkg, packages, installed_set)
                current_pkg = {}
                continue

            if " : " in line:
                key, value = line.split(" : ", 1)
                key = key.strip()
                value = value.strip()
                if key == "Name":
                    current_pkg["name"] = value
                elif key == "Version":
                    current_pkg["version"] = value
                elif key == "Description":
                    current_pkg["description"] = value
                elif key == "Repository":
                    current_pkg["repo"] = value

        # pacman/yay/paru output often has no trailing blank line.
        flush_sync_info(current_pkg, packages, installed_set)
        packages = deduplicate_packages(packages, foreign_names)

        order_map = {name.casefold(): index for index, name in enumerate(popular_names)}
        packages.sort(key=lambda pkg: order_map.get(pkg["name"].casefold(), 999))
        return packages
    except (OSError, subprocess.TimeoutExpired):
        return []


if __name__ == "__main__":
    if "--list-installed" in sys.argv:
        print(json.dumps(get_installed_packages()))
        sys.exit(0)

    if "--list-updates" in sys.argv:
        print(json.dumps(get_updates()))
        sys.exit(0)

    if "--featured" in sys.argv:
        idx = sys.argv.index("--featured")
        cat = sys.argv[idx + 1] if len(sys.argv) > idx + 1 else "featured"
        print(json.dumps(get_featured_packages(cat)))
        sys.exit(0)

    if len(sys.argv) < 2:
        print("[]")
        sys.exit(0)

    query = sys.argv[1]
    print(json.dumps(search_packages(query)))
