# Slide & Seal

> Reconfigure reality. Control the maze. Complete the seal.

A mechanical labyrinth puzzle game for Android, built with Godot 4 and typed GDScript. The player reshapes the maze with gravity, push, portals and other mechanisms to guide an energy core to its seal. There are no timers.

## Status

Early development. Two worlds (levers and gates, then gravity) and three demo levels (energy beams, rotating sections, magnets) are playable in 3D, with free rotate, zoom and pan of the board. All eight designed mechanics are implemented; push and portals have no campaign level yet. Progress is saved: completing a level unlocks the next, and your best result earns up to three stars. All rules are tested headless.

## Running the game

Open `game/` in Godot 4.7.2 and press Play, or run `godot --path game`. The game starts at the home screen.
To jump straight into a level: `godot --path game -- --level=world_05_reflector_logic`.

## Repository

| Path | Contents |
|---|---|
| `game/` | Godot project: scripts, level data, tests |
| `docs/` | Project decisions and the level data schema |
| `tools/` | Developer scripts |
| `Slide_and_Seal_Interactive_Labyrinth_v2/` | Original design package (read-only reference) |

## Requirements

- Godot 4.7.2 (`godot` on `PATH`, or set `GODOT=/path/to/godot`)
- Blender 5.x, only to rebuild the 3D models (`tools/blender/`). Third-party art is CC0; see `game/assets/third_party/polyhaven/LICENSE.md`.

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
