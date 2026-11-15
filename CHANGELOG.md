# Changelog

All notable changes to Slide & Seal are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are dated (YYYY-MM-DD).

## [Unreleased]

### 2026-11-15 — M3b: Touch interaction

**Added**
- **Picking** (`BoardPicker`): screen → block or cell using plain ray math against block boxes and the floor plane. No physics engine. `BoardCoords.world_to_cell` provides the inverse mapping.
- **Gestures** (`BoardInput`, a new node in the gameplay scene): tap and swipe from mouse events, which Godot also emulates from touch.
  - HUD controls consume their own events, so they never reach the board. This was verified through the real input pipeline.
  - Swipe direction is classified against the camera's projection of each grid direction (`CameraRig.screen_vector`).
- **Selection:** tap a block or zone cell. Blocks take priority over the zone beneath. The selection shows an inverted-hull outline on the block or a highlighted zone plate.
  - The tap is refused with a message when the mechanism isn't available in the current context or the block isn't pushable.
- **Mechanism panel** (`MechanismPanel`, `ArrowButton`):
  - Arrows are self-drawn (no font glyphs) and placed by on-screen direction. Unused rows and columns collapse.
  - Zones offer only their allowed directions.
  - Each arrow is enabled only if `PuzzleSession.preview` accepts that action. The current gravity direction is disabled.
  - Hold an arrow to preview, release to commit (P-007).
- **Preview ghosts:** translucent blocks at the cells a push or gravity change would produce (`BoardRenderer3D.show_preview`). They are driven only by `PuzzleSession.preview`.
- **HUD:**
  - an "Available: …" line from `PuzzleSimulator.allowed_mechanisms`
  - the panel sits above the action buttons
  - safe-area margins on mobile (desktop keeps fixed margins)
- **Tests:** 14 interaction tests, bringing the suite to 130. They cover:
  - picking every block and empty zone cells
  - swipe classification and panel slot mapping
  - the unavailable-mechanism message, valid-direction enabling, and hold-to-preview without committing
  - swipe-to-push, swipe-to-gravity, swipe cancel and invalid swipes
  - dropping the selection when the context changes
  - solving the full slice through gestures

**Changed**
- `CameraRig` reserves more space at the bottom (30%) for the panel, so the board isn't covered.
- `GameplayController` now coordinates selection, preview and gestures. All actions still go through `PuzzleSession`.

**Fixed**
- `MechanismPanel` leaked replaced spacer controls. This was found from the engine's leak warnings at exit.

**Verified manually**
- Windowed run with the real input pipeline: a click on a block selects it, a click inside the panel doesn't reach the board, and a button click acts only as the button.
- Screenshots of the block and zone panels with previews. The outline was thickened and the panel compacted after review.

**Known limitations**
- Safe-area handling is untested on a physical Android device.
- No haptics, sound or preview of the core's next travel segment yet.
- Placeholder visuals (D-011).

### 2026-11-15 — M3a: 3D board and playback

**Added**
- **Gameplay scene** `game/scenes/gameplay/gameplay_root.tscn`, now the project's main scene. It has a world environment, a key light, the board, a camera rig, an animation director and the HUD.
- **`GameplayController`:** owns the `PuzzleSession` and routes every change through it. It locks input while a committed result plays back, snaps the board to the committed state afterwards, and asks the simulation (via preview) whether Run is available.
- **Presentation** (`game/scripts/presentation/`):
  - `BoardCoords`: the single grid ↔ world mapping
  - `Palette`: doc 06 colour tokens
  - `BoardRenderer3D`: builds placeholder primitive art (D-011) from level data: tiles, walls, emissive route inlay, checkpoint rings, seal, gravity zone plates with per-cell direction chevrons, blocks, and an octahedron core with glow. It snaps nodes to any `PuzzleState`.
  - `CameraRig`: orthographic isometric camera, fitted to the portrait band between the HUD areas, reframed on resize
  - `AnimationDirector`: plays committed results only. Zone arrows turn first, then the core moves cell by cell, with gravity slides following the step that triggered them. A push plays first, then gravity slides together. The `instant` mode doubles as reduced motion.
- **UI:** `HudController` shows the title, phase status, the action count against the target and rejection messages, and provides Undo / Restart / Run–Resume. It uses a palette-based theme. Non-interactive areas ignore input, ready for M3b board taps.
- `PuzzleSession.is_at_initial_state()`.
- **Tests:** 5 scene integration tests, bringing the suite to 116. The board mirrors the committed state after every step of the full slice solution, after a rejection, and after undo and restart. HUD availability is checked too.
- **Decisions:** D-011 (placeholder art first) and D-012 (tap and swipe input, built in M3b).

**Changed**
- The test runner now runs tests on the first frame instead of in `_initialize`. Before that, the root viewport isn't in the tree, so scenes added by tests never received `_ready`.

**Verified manually**
- Rendered in a window, playing the slice solution with real animation: the run, push, gravity turn and slides, travel and completion all render matching the committed state.
- A camera projection check confirmed the zone chevrons point in the simulated direction. The chevrons were then lengthened for clearer reading.

**Known limitations**
- No touch input yet; push and gravity can't be triggered in-game until M3b.
- Placeholder art. Walls can partly hide cells behind them at this camera angle (for example next to the seal). Revisit in polish.
- Safe-area insets are not yet applied (fixed 48px margins).

### 2026-11-15 — M2: Gravity Shift and Push Pulse

**Added**
- **Gravity Shift** (`GravityResolver`, `PuzzleAction.set_gravity`): local rectangular zones with a player-settable direction (D-006).
  - Gravity is persistent: every committed state is settled, including after each core step during travel.
  - Resolution order is deterministic: farthest along gravity first, then by id.
- **Push Pulse** (`PuzzleAction.push`): moves any pushable object one cell (D-007).
  - No chains. Pushes into walls, bounds, objects or the core are rejected.
  - Gravity settles after each push. A push with no net effect is rejected.
- **Mechanism availability** (`PuzzleSimulator.allowed_mechanisms`): setup, checkpoint and blocked contexts (D-008).
- **Model:**
  - `Grid.Direction`
  - `MechanismIds`
  - `GravityZoneDefinition`
  - `ObjectMove`: per-object moves with their cause and core step, for upcoming animation
  - object flags `pushable` and `gravity_affected`
  - `PuzzleState.gravity_directions`, included in the state key
- **Level schema v3 extensions:**
  - `setup.allowed_mechanisms`, object flags and `gravity_zones`
  - validation of zone bounds, overlap and directions
  - mechanism availability must make sense: something to act on, implemented mechanisms only
  - the authored start state must already be settled
- **Vertical slice level** `game/data/levels/world_01_slice.json` (D-010): three beats (push, gravity, combined) and a target of 4 actions. Its tests cover the intended solution, beat order, closed skips and the minimum of 4.
- **Test-only exhaustive search** `TestSolver`, in `tests/support`, the precursor of the M4 solver. Core runs are free and mechanism actions cost one, so it finds the true minimum.
- `PuzzleState.to_key(include_counters)`: lets search merge boards that differ only in their counters.
- **Tests:** 54 new, bringing the suite to 111, all passing. Covers gravity, push, mechanism context and the new loader rules. Mutation checks confirmed the ordering and in-travel settling tests fail when that logic is broken.
- **Docs:**
  - decisions D-006 to D-010
  - P-001 to P-006 marked approved
  - `docs/LEVEL_SCHEMA.md` updated

**Changed**
- New failure codes: `MECHANISM_NOT_ALLOWED`, `INVALID_TARGET`, `INVALID_DIRECTION`, `MOVE_BLOCKED`, `NO_EFFECT`.
- Core travel now reports gravity moves triggered by the cells it vacates.
- The shipped-level test now requires every level to be solvable within its `target_actions`, using `TestSolver`, and replays the solution through `PuzzleSession`. It previously only tried running the core.

**Known limitations**
- There is no push-until-blocked mode (`push_devices`). That is deferred per doc 03.
- `TestSolver` is test-only and bounded at 200k states. The production solver arrives in M4.

### 2026-11-15 — Repository README

**Added**
- Root `README.md`: a short overview covering the layout, requirements and test command. `CLAUDE.md` now says to update it only when its content becomes wrong.

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
