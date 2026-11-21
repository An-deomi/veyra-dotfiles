#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json

import emoji

out = []
for ch, d in emoji.EMOJI_DATA.items():
    if d.get("status") != emoji.STATUS["fully_qualified"]:
        continue
    names = [n.strip(":").lower() for n in [d.get("en", "")] + list(d.get("alias", []))]
    if not names[0] or "skin_tone" in names[0]:
        continue
    out.append({"e": ch, "n": names[0], "a": names[1:]})

print(json.dumps(out))
