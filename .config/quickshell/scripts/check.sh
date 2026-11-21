#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONDONTWRITEBYTECODE=1

printf '\n== Python unit tests ==\n'
python3 -m unittest discover -s Tests -v

printf '\n== Python syntax ==\n'
python3 - <<'PY'
import ast
from pathlib import Path

files = sorted(Path('.').rglob('*.py'))
for path in files:
    if any(part in {'__pycache__', '.git'} for part in path.parts):
        continue
    ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
print(f'Validated {len(files)} Python files.')
PY

printf '\n== Shell syntax ==\n'
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find . -type f -name '*.sh' -print0)
printf 'Validated shell scripts.\n'

printf '\n== JSON and SVG assets ==\n'
python3 - <<'PY'
import json
import xml.etree.ElementTree as ET
from pathlib import Path

json_files = sorted(Path('.').rglob('*.json'))
svg_files = sorted(Path('.').rglob('*.svg'))
for path in json_files:
    if any(part in {'__pycache__', '.git'} for part in path.parts):
        continue
    json.loads(path.read_text(encoding='utf-8'))
for path in svg_files:
    ET.parse(path)
print(f'Validated {len(json_files)} JSON files and {len(svg_files)} SVG files.')
PY

if command -v /usr/lib/qt6/bin/qmllint >/dev/null 2>&1; then
    QML_LINT=/usr/lib/qt6/bin/qmllint
elif command -v qmllint >/dev/null 2>&1 && qmllint --version 2>/dev/null | grep -q '^6\.'; then
    QML_LINT=qmllint
else
    QML_LINT=""
fi

if [ -n "$QML_LINT" ]; then
    printf '\n== QML syntax (Qt 6 qmllint) ==\n'
    mapfile -d '' qml_files < <(find . -type f -name '*.qml' -print0)
    if ((${#qml_files[@]})); then
        # Import/type warnings are expected outside a live Quickshell session.
        # Only real syntax errors should fail the check.
        output="$("$QML_LINT" -I "$ROOT" -I /usr/lib/qt6/qml "${qml_files[@]}" 2>&1 || true)"
        if grep -q '\[syntax\]' <<<"$output"; then
            grep '\[syntax\]' <<<"$output"
            printf 'QML syntax errors found.\n' >&2
            exit 1
        fi
        printf 'No QML syntax errors in %d files (import/type warnings ignored).\n' "${#qml_files[@]}"
    fi
else
    printf '\n[SKIP] Qt 6 qmllint is not installed; run `qs log` in a live session to validate QML.\n'
fi

printf '\n== QML duplicate signal handlers ==\n'
python3 - <<'PY'
import re
import sys
from pathlib import Path

# Declaring the same on<Property>Changed handler twice on one object is legal
# QML but a hard runtime error ("Property value set multiple times") that makes
# the whole object unavailable — that took the entire shell down once. Only
# singletons are scanned, and only handlers at root indentation, so nested
# objects that shadow a property name are not false positives.
property_re = re.compile(r'^    (?:readonly\s+)?property\s+[\w.]+\s+(\w+)', re.MULTILINE)
handler_re = re.compile(r'^    on([A-Z]\w*)Changed\s*:', re.MULTILINE)
problems = []

for path in sorted(Path('.').rglob('*.qml')):
    if any(part in {'__pycache__', '.git'} for part in path.parts):
        continue
    text = path.read_text(encoding='utf-8')
    if 'pragma Singleton' not in text:
        continue
    declared = {name.lower() for name in property_re.findall(text)}
    seen = {}
    for handler_name in handler_re.findall(text):
        key = handler_name.lower()
        seen.setdefault(key, [handler_name, 0])
        seen[key][1] += 1
    for key, (original, count) in seen.items():
        if count > 1 and key in declared:
            problems.append(f'{path}: on{original}Changed declared {count} times')

if problems:
    print('\n'.join(problems))
    print('Duplicate handlers found.')
    sys.exit(1)
print('No duplicate property handlers.')
PY

printf '\nAll available checks passed.\n'
