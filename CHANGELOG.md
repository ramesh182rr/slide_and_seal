# Changelog

All notable changes to Slide & Seal are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are dated (YYYY-MM-DD).

## [Unreleased]

### 2026-11-15 — M1: Headless simulation foundation

**Added**
- **Godot project** at `game/` (Godot 4.7.2, Mobile renderer, portrait 1080×1920, `canvas_items` stretch). Untyped GDScript declarations are configured as errors, which enforces typed GDScript.
- **Model** (`game/scripts/model/`):
  - level data: `LevelDefinition`, `RouteDefinition`, `CheckpointDefinition`
  - runtime state: `PuzzleState`, `MovableObject`
  - actions and results: `PuzzleAction`, `ActionResult`, `CoreTravelResult`
  - helpers: `Grid`

  `PuzzleState.to_key()` gives a canonical serialization of every field, used for equality, undo checks and the future solver.
- **Simulation** (`game/scripts/simulation/`):
  - `PuzzleSimulator`: pure, deterministic rules for core travel. One `RUN_CORE` action covers Run and Resume. It handles checkpoint auto-pause, blocking by movable objects (`BLOCKED_WAITING_FOR_ACTION`) and completion. `preview_action` uses the same rule path as `apply_action`.
  - `PuzzleSession`: committed state plus undo history. Undo covers core travel too. Restart is exact and undoable.
  - `LevelLoader`: strict level schema v3 loading and validation. A level with any error is rejected whole.
- **Level data:** `game/data/levels/world_01_level_001.json`, "The First Signal", converted from the package example to schema v3. The original file is unchanged.
- **Tests:**
  - custom headless runner `game/tests/run_tests.gd` plus `tools/run_tests.sh`. Engine or script errors raised during a test fail that test.
  - 57 tests across unit, integration and shipped-level suites
- **Docs:**
  - `docs/DECISIONS.md`: approved decisions D-001 to D-005 and provisional choices P-001 to P-006
  - `docs/LEVEL_SCHEMA.md`: schema v3, filling the missing `14_Level_Data_Schema.md`
- `.gitignore`: covers `.godot/`, `.DS_Store`, Android build output and signing material.

**Decisions**
- Approved:
  - slice level includes gravity and push (D-001)
  - `game/` layout (D-002)
  - authored route segments (D-003)
  - custom test runner (D-004)
  - portrait (D-005)
- Provisional, awaiting review: P-001 to P-006 in `docs/DECISIONS.md`. These cover atomic travel, a single run/resume action, rejecting a run into an immediately blocked cell, checkpoint-on-enter, undoable restart and schema v3.

**Known limitations**
- There are no mechanisms yet. The loader rejects non-empty mechanism collections until their resolvers exist, so `BLOCKED_WAITING_FOR_ACTION` can only be cleared by undo or restart.
- There is a single route segment per level, with no junctions yet.
- There are no scenes, rendering or UI yet.
- Undo history is unbounded.
- "Completable" in the shipped-level test means running the core reaches the seal. The BFS solver arrives in M4.

### 2026-11-15 — Project initialization audit

**Added**
- `CLAUDE.md`: permanent development instructions covering the Git/no-commit policy, the changelog policy, architecture rules (deterministic simulation as source of truth, separate presentation/UI, no physics-driven outcomes, no timers), the design-change policy, the working method and the verified toolchain.
- `CHANGELOG.md`: this file.

**Audit findings (no code changed)**
- The repository holds the Slide & Seal design/reference package v2.0 (`Slide_and_Seal_Interactive_Labyrinth_v2/`): 18 design docs, concept art, 8 SVG mechanic glyphs, an example level JSON and a daily schedule template.
- No Godot project exists yet (`godot_project/` holds only placeholder READMEs). There is no code and no executable test suite.
- The repository has no commits yet. All files are untracked.

**Known gaps**
- `docs/08` references `14_Level_Data_Schema.md`, which does not exist. The level schema is currently defined only by `data/levels/level_001_example.json`.
- The open design decisions in `docs/18` are unresolved.
