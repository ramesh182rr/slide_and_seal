# Slide & Seal

> Reconfigure reality. Control the maze. Complete the seal.

A mechanical labyrinth puzzle game for Android, built with Godot 4 and typed GDScript. The player reshapes the maze with gravity, push, portals and other mechanisms to guide an energy core to its seal. There are no timers.

## Status

Early development. The vertical slice level is playable in 3D: tap or swipe blocks and gravity zones, preview before committing, and use undo and restart. All rules are tested headless.

## Running the game

Open `game/` in Godot 4.7.2 and press Play, or run `godot --path game`.

## Repository

| Path | Contents |
|---|---|
| `game/` | Godot project: scripts, level data, tests |
| `docs/` | Project decisions and the level data schema |
| `tools/` | Developer scripts |
| `Slide_and_Seal_Interactive_Labyrinth_v2/` | Original design package (read-only reference) |

## Requirements

- Godot 4.7.2 (`godot` on `PATH`, or set `GODOT=/path/to/godot`)

## Running the tests

```sh
tools/run_tests.sh
```

Exit code `0` means every test passed.

## Validating levels

```sh
tools/validate_levels.sh
```

This checks every level: whether it is solvable, its proven minimum moves, and possible softlocks.

## Further reading

- `Slide_and_Seal_Interactive_Labyrinth_v2/README.md`: game design overview
- `docs/DECISIONS.md`: approved design and technical decisions
- `docs/LEVEL_SCHEMA.md`: level JSON format
- `CHANGELOG.md`: change history
