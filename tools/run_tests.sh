#!/usr/bin/env bash
# Runs the headless Slide & Seal test suite. Exit code 0 = all tests passed.
# Usage: tools/run_tests.sh        (override the binary with GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Import pass refreshes the global class cache so class_name types resolve in --script mode.
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null
"$GODOT" --headless --path "$ROOT/game" --script res://tests/run_tests.gd
