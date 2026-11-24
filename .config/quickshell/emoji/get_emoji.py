#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
TEST_FILES = [
    os.path.join(HERE, "emoji-test.txt"),
    "/usr/share/unicode/emoji/emoji-test.txt",
]

COMMENT_RE = re.compile(r"^\S+\s+E\d+\.\d+\s+(.+)$")


def normalize_name(raw):
    slug = re.sub(r"[^a-z0-9]+", "_", raw.lower()).strip("_")
    return slug


def parse_emoji_test():
    for path in TEST_FILES:
        if not os.path.isfile(path):
            continue
        entries = []
        seen = set()
        group = ""
        subgroup = ""
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("# group:"):
                    group = line.split(":", 1)[1].strip()
                    continue
                if line.startswith("# subgroup:"):
                    subgroup = line.split(":", 1)[1].strip()
                    continue
                if not line or line.startswith("#"):
                    continue
                try:
                    code, rest = line.split(";", 1)
                    qual, comment = rest.split("#", 1)
                    if qual.strip() != "fully-qualified":
                        continue
                    ch = "".join(chr(int(c, 16)) for c in code.split())
                except ValueError:
                    continue
                if ch in seen:
                    continue
                m = COMMENT_RE.match(comment.strip())
                raw_desc = m.group(1).strip() if m else comment.strip()
                name = normalize_name(raw_desc)
                if not name or "skin_tone" in name:
                    continue
                seen.add(ch)
                aliases = []
                if subgroup:
                    sub_slug = normalize_name(subgroup)
                    if sub_slug and sub_slug != name:
                        aliases.append(sub_slug)
                entries.append({"e": ch, "n": name, "a": aliases, "g": group})
        return entries
    return []


def main():
    entries = parse_emoji_test()
    try:
        import emoji as emoji_pkg  # Optional enrichment if installed

        extra_aliases = {}
        for ch, d in emoji_pkg.EMOJI_DATA.items():
            if d.get("status") != emoji_pkg.STATUS["fully_qualified"]:
                continue
            names = [n.strip(":").lower() for n in [d.get("en", "")] + list(d.get("alias", []))]
            names = [n for n in names if n and "skin_tone" not in n]
            if names:
                extra_aliases[ch] = names
        if entries:
            for item in entries:
                for alias in extra_aliases.get(item["e"], []):
                    if alias != item["n"] and alias not in item["a"]:
                        item["a"].append(alias)
        else:
            for ch, names in extra_aliases.items():
                entries.append({"e": ch, "n": names[0], "a": names[1:], "g": ""})
    except ImportError:
        pass

    print(json.dumps(entries, ensure_ascii=False))


if __name__ == "__main__":
    main()
