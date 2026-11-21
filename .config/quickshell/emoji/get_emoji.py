#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os

import emoji

HERE = os.path.dirname(os.path.abspath(__file__))
TEST_FILES = [
    os.path.join(HERE, "emoji-test.txt"),
    "/usr/share/unicode/emoji/emoji-test.txt",
]

groups = {}
order = {}
for path in TEST_FILES:
    if not os.path.isfile(path):
        continue
    group = ""
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("# group:"):
                group = line.split(":", 1)[1].strip()
                continue
            if not line or line.startswith("#"):
                continue
            try:
                code, rest = line.split(";", 1)
                if rest.split("#", 1)[0].strip() != "fully-qualified":
                    continue
                ch = "".join(chr(int(c, 16)) for c in code.split())
            except ValueError:
                continue
            groups[ch] = group
            order[ch] = len(order)
    break

out = []
for ch, d in emoji.EMOJI_DATA.items():
    if d.get("status") != emoji.STATUS["fully_qualified"]:
        continue
    names = [n.strip(":").lower() for n in [d.get("en", "")] + list(d.get("alias", []))]
    if not names[0] or "skin_tone" in names[0]:
        continue
    out.append({"e": ch, "n": names[0], "a": names[1:], "g": groups.get(ch, "")})

out.sort(key=lambda x: order.get(x["e"], 10**6))
print(json.dumps(out))
