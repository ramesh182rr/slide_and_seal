#!/usr/bin/env bash
# Validates every level in game/data/levels: schema, solvability, proven minimum, dead ends.
# Exit code 0 = no errors. Usage: tools/validate_levels.sh   (override binary with GODOT=...)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$GODOT" --headless --path "$ROOT/game" --import >/dev/null
"$GODOT" --headless --path "$ROOT/game" --script res://tools/validate_levels.gd
