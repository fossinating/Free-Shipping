#!/usr/bin/env bash
# Runs the headless test suite. Set GODOT to your Godot 4.6 binary.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import </dev/null >/dev/null 2>&1 || true
exec "$GODOT" --headless --path . res://tests/run_tests.tscn -- "$@" </dev/null
