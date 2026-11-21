#!/usr/bin/env bash
# Runs your AUR helper (paru preferred, then yay) with the given arguments.
for h in paru yay; do
  if command -v "$h" >/dev/null 2>&1; then exec "$h" "$@"; fi
done
echo "No AUR helper found. Install paru or yay first." >&2
exit 127
