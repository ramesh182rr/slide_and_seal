# Changelog

All notable changes to Slide & Seal are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are dated (YYYY-MM-DD).

## [Unreleased]

### 2026-11-15 — M7b: Energy routing in 3D, plus "Reflector Logic"

**Added**
- **Level** `game/data/levels/world_05_reflector_logic.json`, "Reflector Logic" (doc 09 #28), placed after the showcase in "The Sealed Chambers":
  - an emitter, two mirrors that both need flipping, and a receiver powering the gate on the core's corridor
  - the validator proves a minimum of 2 with 0 dead ends
- **`MechanismFixtures3D`:**
  - emitter (block plus nozzle), mirror (slab on a base, turned per orientation), receiver (pedestal plus crystal lamp)
  - beams drawn from `EnergyResolver.trace`, rebuilt after every committed state, with a stub to the obstacle that stopped them
  - `beam_signature` for preview comparison
- **Preview:** ghost beam paths (mint) whenever a previewed action changes the beams.
- **Playback:** mirrors swing to their new diagonal.
- **Interaction:**
  - tap a mirror for a "Flip mirror" panel (hold to preview, release to flip)
  - tapping a receiver or emitter explains it
  - HUD: "Energy" and "Tap a mirror"
- **Tests:** 5 scene tests, bringing the suite to 283. They cover:
  - mirrors, receiver lamp and beam drawing matching state, including after undo
  - the explanatory taps and "not before the checkpoint"
  - the flip panel with its beam preview, committed through the real button signal
  - solving the full level through taps

**Changed**
- Catalog: Reflector Logic inserted before Quarter Turn, and the navigation tests updated.
- The mirror panel title no longer shows `/` or `\`, since the isometric view would make it misleading.

**Verified**
- Windowed screenshots: the initial beam, the ghost preview of the new path, both mirrors flipped with receiver A lit and gate A open, and completion.
- All five levels validate.

**Known limitations**
- Placeholder art. Beams are plain glowing boxes, with no particles or animated flow.
- Beams redraw once a playback finishes rather than animating along their new path.

### 2026-11-15 — M7a: Energy Routing (rules)

**Added**
- **`EnergyResolver`:** traces beams from active emitters.
  - Beams stop at walls (including turned section walls), closed gates, blocks, emitters and the board edge.
  - They bend at reflectors (`ReflectorDefinition.reflect`) and end on the first receiver.
  - A loop guard and a step bound mean tracing can never hang.
- **Power:** powered receivers are computed bottom-up to a stable result (`update_power`), so chains work: a receiver can open a gate on another beam's path or start another emitter. Power is re-evaluated in every settle pass and in the initial state.
- **Switch kind `receiver`** (D-024): on while powered, so gates, portals and emitters can require it. All gate rules apply.
- **Emitters** (`mechanisms.energy_emitters`) with optional `requires` (D-025); **reflectors** (`mechanisms.reflectors`, `/` or `\`).
- **`PuzzleAction.flip_reflector`** (mechanism `energy_routing`, D-022), counted as one action. Mirror orientation is in the state key.
- **Solid fixtures:** emitters and reflectors block blocks and the core (`LevelDefinition.is_solid_fixture`, used by `is_wall_at` and gravity). Beams use the separate `is_terrain_wall_at`.
- **Loader:** energy fixtures validated (cells, routes, sharing, requires, blocks inside fixtures, sections). Allowing `energy_routing` requires a reflector, and allowing `rotating_sections` requires a section.
- The solver includes reflector flips.
- **Tests:** 20 new, bringing the suite to 278. They cover:
  - the reflection table, initial and flipped beams, flipping opening the gate and completing the level
  - blocks and closed gates stopping beams, switch-controlled emitters, power chains
  - solidity, never closing a gate on the core when a beam is cut
  - rejections, undo/preview/key, the solver minimum
  - 8 loader rules

**Changed**
- Two loader tests updated: the switch-kind message now lists `receiver`, and the "unsupported mechanism" example now uses `magnetic_fields`.

**Verified**
- Mutation checks: transparent blocks, single-pass power and no power refresh in settling are each caught.
- All four shipped levels validate unchanged.

**Known limitations**
- Rules only: beams, emitters, mirrors and receivers are not drawn or interactive in 3D yet.
- Energy fixtures inside rotating sections are not supported yet.

### 2026-11-15 — D-021: track pieces are entered only when passable

**Changed**
- **Rule:** at a junction the core enters a track piece only if it can pass straight through:
  - the piece's far end lines up with a corridor, and
  - every piece cell plus that corridor's first cell is free.

  Otherwise it waits outside the section, where it can still be turned (`PuzzleSimulator._can_pass_through`). The owner approved "enter only when both ends connect"; the free-passage condition extends it so a block cannot strand the core either.
- **Quarter Turn** now validates with **0 dead ends**. The overshoot trap is gone.
- **Tests:** the D-019 safeguard ("no turning with the core inside") is now tested with a hand-built state, since normal play can no longer put the core inside a section. The undo test no longer relies on a stranded core.

**Added**
- 3 tests: waiting outside when the exit corridor is blocked; waiting outside when a block sits on the piece; regression test for the Quarter Turn overshoot. Suite: 258. A mutation check confirmed that disabling the rule fails exactly these three.

### 2026-11-15 — M6b: Rotating sections in 3D, plus "Quarter Turn"

**Added**
- **Level** `game/data/levels/world_06_quarter_turn.json`, "Quarter Turn" (doc 09 #32), in the new catalog world "The Shifting Labyrinth":
  - a clockwise-only 3×3 turntable with an L-shaped track piece; two turns connect the corridor to the seal corridor
  - a fixed crate rides the turntable
  - the validator proves a minimum of 2
- **Renderer:**
  - section pivots carry the tiles, walls and track inlay inside each section, turned to the current orientation
  - fixed amber frame (cyan when selected) and an off-centre hub
  - preview ghosts show where track pieces and blocks would end up after a turn
- **Playback:** the platform turns smoothly, and blocks on it orbit the centre in step.
- **Interaction:**
  - tap a section to open a panel with one button per allowed direction (hold to preview, release to turn)
  - the panel explains when the core is on the section
  - HUD: "Rotation" and "Tap a rotating section"
- `MechanismPanel` action mode supports up to two buttons (`show_actions`), created once and reused.
- **Tests:** 5 Quarter Turn scene tests, bringing the suite to 255. They cover:
  - platform and crate visuals matching state, including after undo
  - the unavailable-section message
  - the clockwise-only panel and the track/crate preview, committed through the real button signal
  - solving the full level through taps

**Changed**
- Fixed (non-pushable) blocks are drawn grey steel instead of slate, to stand apart from walls.
- Navigation tests updated for four catalog levels; Quarter Turn is now the last level.

**Found by the validator during design**
- The first draft started the L already connected to the incoming corridor, so "run, run" stranded the core inside the turntable. The start orientation was changed.
- One recoverable trap remains by nature of L pieces: turning a third time and running. It is reported as 1 dead end; undo recovers. A rule alternative is raised in P-014.

**Known limitations**
- Placeholder art. The mid-turn screenshot was taken at the start of the turn, so the turning animation is covered by tests of the final platform angle rather than visual review.

### 2026-11-15 — M6a: Rotating Sections (rules)

**Added**
- **`RotatingSectionDefinition`:** square sections with quarter-turn `rotate_cell` / `authored_cell`, and per-section allowed directions (D-020).
- **`PuzzleAction.rotate_section(id, clockwise)`** (mechanism `rotating_sections`):
  - turns the section, moving the blocks inside it (one-to-one remap, `ObjectMove.Cause.ROTATION`)
  - then stabilises and applies the occupied-gate rule
  - rejected while the core is inside (D-019)
- **State:** `PuzzleState.section_turns` and `core_route_reversed`, both in the state key.
- **Track pieces** (D-017): route segments wholly inside a section turn with it.
  - The core leaves a fixed segment's open end into whichever end of a piece is currently adjacent (forwards or in reverse), then leaves the piece into the fixed segment starting beside its far end.
  - If nothing lines up, the core waits until the section is turned.
- **Rotation-aware rules:** `PuzzleSimulator.route_cell` / `is_wall_at` turn walls and route nodes inside sections (D-018). Pushes and core blocking use them.
- **Loader:**
  - parses `mechanisms.rotating_sections`
  - classifies track pieces
  - first-version limits: no switches, gates, portals, checkpoints, core start or destination inside a section
  - **validates every possible connection**: each fixed segment ends at the destination, a portal entry or beside exactly one section; no two fixed starts share a section cell; the possible-successor graph reaches the destination and every segment, with no loops
- The solver includes rotations.
- **Tests:** 23 new, bringing the suite to 250. They cover:
  - rotation geometry and its inverse
  - waiting when misaligned; clockwise (reverse travel) and counterclockwise (forward travel) connections
  - no turning with the core inside
  - walls and blocks turning, blocks outside untouched, pushes respecting turned walls
  - rejections, four turns returning to identity, undo, preview, the solver minimum
  - 9 loader rules

**Changed**
- Route linking is now validated as a graph of possible connections instead of a single fixed chain. Portal links are recorded as before. Error wording for segments that end nowhere changed accordingly, and 4 existing loader tests were updated.
- Core travel is bounded by `MAX_TRAVEL_STEPS` as a defensive guard, on top of the loader's no-loop guarantee.

**Verified**
- Mutation checks: allowing turns with the core inside, dropping reverse track travel, and ignoring turned walls are each caught.
- All three shipped levels validate with identical results.

**Known limitations**
- Rules only: sections are not yet drawn as turning platforms or interactive in 3D. The renderer would still draw track pieces at their authored orientation, and no shipped level uses sections yet.
- Switches, gates, portals and checkpoints inside sections are not supported yet.

### 2026-11-15 — Save data, progress and unlocking

**Added**
- **`ProgressStore`** (`user://progress.json`, versioned):
  - records per-level completion and best action count
  - crash-safe writes (temp file, then backup, then rename)
  - on load, unreadable or unsupported files are set aside as `.corrupt`, with fallback to the backup, then to a fresh start (P-013)
- **`Progression`:** sequential unlocking in catalog order (D-016) and stars per doc 01 §10. Three stars only when a solver-proven optimum exists.
- **Level select:** locked levels are disabled and marked "Locked"; completed levels show "Best N" and drawn stars (`StarRating`, no font-glyph dependency).
- **Completion card:** stars for this run and "New best!". `AppRoot` saves on each completion (`GameplayController.level_completed`) and passes the previous best to gameplay.
- `LevelCatalog.Entry` carries `target_actions` / `optimal_actions`.
- **Test infrastructure:**
  - `TestCase.after_each()` hook, called by the runner after every test
  - `TestFiles.remove_progress()`, which refuses to touch the real save file
- **Tests:** 13 new, bringing the suite to 227:
  - `ProgressStore`: best tracking, round trip, backup on save, recovery from a corrupt save via the backup, fresh start without a backup, unsupported schema
  - `Progression`: unlocking and stars
  - end-to-end: locks on a fresh profile, completion saving and unlocking the next level, persistence across app restarts, a worse replay keeping the record with no "New best!"

**Fixed** (during this milestone)
- The navigation tests briefly wrote to the real `user://progress.json`, once completions started saving. The files created by that run held only test completions and were removed. All app tests now use scratch save paths cleaned after each test.

**Verified**
- Windowed screenshots: a fresh level list with locks, the completion card with three stars and "New best!", and the level list afterwards (Best 0 ★★★, level 2 unlocked, level 3 locked).

**Known limitations**
- No "reset progress" option yet (a settings screen does not exist).
- Premium access (`access: "premium"`) is not enforced; all catalog levels follow the same unlock rule.
- No cloud sync (doc 17 post-launch).

### 2026-11-15 — Menu skeleton

**Added**
- **`AppRoot`** (`game/scenes/app/app_root.tscn`, now the main scene): Home → Level select → Gameplay, one screen at a time.
  - Leave and the completion card return to level select.
  - The dev `--level=<id>` option moved here.
- **`LevelCatalog`** with `game/data/catalog.json`: play order and world grouping. Each entry is loaded through `LevelLoader`, and duplicates or mismatched ids are reported.
- **Screens:** `HomeScreen` (title, tagline, Play) and `LevelSelectScreen` (levels numbered in play order under world headings; all open until save data exists).
- **`CompletionCard`** in the HUD: actions against target ("Target met" when achieved), Level select, and Next level (hidden on the last level). It appears after the completing playback, and Undo hides it.
- **Back / Escape:** level select → home, home → exit. Gameplay keeps its own Back handling.
- **`UiTheme`:** shared styling, extracted from the HUD, including `apply_safe_margins`, which level select now uses too.
- **Tests:** 10 navigation tests, bringing the suite to 214. They cover:
  - the catalog order, and every level file being listed
  - Home → Level select → Gameplay with the right level, and Leave → level select
  - the Back chain, and Back in gameplay being left to the gameplay controller
  - Next level, no Next on the last level, and Undo hiding the card

**Fixed** (during this milestone)
- The level-select resize listener was first connected through a static function, so it outlived the screen and collided on the second visit. Caught by the tests; it is now an instance method.

**Verified**
- Windowed screenshots of Home, Level select and the completion card.
- The Android export still builds, and `catalog.json` is packaged.

**Known limitations**
- No save data, progress, stars or unlocking yet.
- Placeholder screens. The doc 06 world dioramas, splash, settings and store are not built.

### 2026-11-15 — M5c: Switches, gates and portals in 3D, plus showcase level

**Added**
- **Showcase level** `game/data/levels/world_05_showcase.json`, "Sealed Passage — Showcase" (7×8). It has three beats: a lever opens gate A, block K pushed onto a plate opens gate B, and a lever powers portal 1 into a walled-off area with the seal. The validator proves a minimum of 3 actions with **0 dead ends**, and `optimal_actions` is 3.
- **`MechanismFixtures3D`:**
  - placeholder visuals for toggle levers, pressure plates, gates (closed standing / open sunk) and portals (entry swirl disc, active glow)
  - billboard link symbols (P-011)
  - state sync, and preview ghosts for gates a preview would change
- **`MaterialLibrary`:** shared material cache, extracted from the board renderer.
- **Gate animation:** gates that change rise or sink after the moves that caused them.
- **Interaction:**
  - tap a toggle switch to select it (cyan ring); the panel's new single-action mode gives a "Switch on/off" button with hold-to-preview / release-to-commit
  - tapping a pressure plate, gate or portal explains what powers it
  - the HUD availability line now separates "tap or swipe" targets from tap-only switches
- **Development level selection:** `godot --path game -- --level=<id>`.
- **Tests:** 7 showcase-scene tests, bringing the suite to 204. They cover:
  - link symbols and labels
  - fixture visuals matching state (initial, after toggle, after undo, at completion)
  - the lever panel with its gate preview, committed through the real button signal
  - explanatory taps, and the switch-availability message
  - solving the full showcase through taps and swipes

**Verified manually**
- Windowed screenshots through the whole showcase with real animation: the lever ring and panel, gate A opening, the plate pressed by K, the portal powering up, and completion.
- Review fixes: the gate-opening preview was invisible (a ghost inside the closed gate) and is now a glowing shell. The hint "Tap or swipe a switch" now reads "Tap a switch".

**Known limitations**
- Placeholder art. Gates and blocks are both cube-shaped, distinguished by colour, letter label and height.
- No portal transit effect beyond the instant jump.
- No level-select menu yet; other levels are opened with the `--level` argument.

### 2026-11-15 — M5b: Portal Network (rules)

**Added**
- **Multiple route segments linked by portals** (D-003 junctions):
  - `PortalDefinition` with optional `exit` and `requires`.
  - The loader follows the chain from the start segment and records `RouteDefinition.exit_portal_id` / `next_route_id`.
  - It rejects segments that end nowhere, unknown or self exits, exits where no segment starts, loops, unreachable segments, portals inside a segment, and cells shared across segments.
- **Teleport travel** (D-015, core only): stepping into an entry portal continues from the exit cell in the same step; the core never rests on the entry. The entry counts as blocked if it is occupied, the portal is inactive (its `requires` switches aren't all on) or the exit cell is blocked.
- `CoreTravelResult.portal_steps` marks teleport arrivals. `AnimationDirector` jumps the core there instead of sliding across the board (a placeholder until portals are rendered).
- `SwitchGateResolver.is_portal_active`; `LevelDefinition.portal_by_id` / `portal_at`.
- **Tests:** 19 new (10 rules, 9 loader), bringing the suite to 197. Mutation checks confirmed the occupied-exit and inactive-portal rules are each caught.

**Changed**
- Routes may now have several segments. The "exactly one segment" rule is replaced by chain validation, and the destination must end the final segment.
- `_run_core` advances via a single `_next_step` helper that handles normal steps and portal transits.

**Verified**
- Both shipped levels validate with identical results.

**Known limitations**
- Rules only: portals, switches and gates are not drawn or interactive in the 3D scene yet.
- `portal_network` has no player action (portals are fixed or switch-controlled), so levels cannot list it in `allowed_mechanisms`.

### 2026-11-15 — M5a: Switches & Seals (rules)

**Added**
- **Switches** (`SwitchDefinition`):
  - `pressure` switches are on while a block rests on them; the core never presses them (D-014).
  - `toggle` switches are flipped by the new `PuzzleAction.toggle_switch` (mechanism `switches_seals`), and their state is stored in `PuzzleState.toggle_states`, which is included in the state key.
- **Gates** (`GateDefinition`): open when all `requires` switches are on. A closed gate blocks the core, pushes and gravity.
- **`SwitchGateResolver`:** switch and gate state is always derived from positions and toggles, never stored.
- **`PuzzleSimulator.stabilize`:** gravity settles, gates are re-evaluated, and this repeats until nothing moves. It is used by every action, by core travel and by the loader's start-state check. Each object's move is merged into one start → rest move for animation.
- **D-013 rule:** any action whose result would leave a closed gate on a block or the core is rejected with the new failure `GATE_OCCUPIED`. This includes a Run, when gravity during travel would release a switch.
- **Loader** (schema v3, backward compatible): `mechanisms.switches` and `mechanisms.gates`, validated as described in `docs/LEVEL_SCHEMA.md`. `switches_seals` is now an implemented mechanism.
- The solver includes toggle actions.
- **Tests:** 26 new (17 rules, 9 loader), bringing the suite to 178. Mutation checks confirmed the travel gate check, iterative stabilisation and gate blocking are each caught by their tests.

**Verified**
- Both shipped levels still validate with identical results (slice: minimum 4, 536 dead ends, 17 unknown), so there is no behaviour change for existing content.

**Decisions:** D-013 (reject, never close an occupied gate), D-014 (blocks only press switches) and D-015 (portals carry the core only).

**Known limitations**
- Rules only: switches and gates are not yet rendered or interactive in the 3D scene, and no shipped level uses them.
- Portals are next (M5b).

### 2026-11-15 — Android Back handling and panel fixes

**Added**
- **Back / Escape handling** (P-009): `application/config/quit_on_go_back=false`. `GameplayController.handle_back()` responds to `NOTIFICATION_WM_GO_BACK_REQUEST` and `ui_cancel`. It closes the leave dialog, then the mechanism panel, then asks to leave.
- **`LeaveDialog`:** a modal "Leave this puzzle?" with Stay / Leave and a full-screen dimmer that blocks input to the board. Leave emits `leave_requested` and quits; `quit_on_leave` can be turned off for tests.
- **Tests:** 7 Back-navigation tests (including the dialog covering the whole screen) and a regression test that presses the real arrow button. Suite: 152.

**Fixed**
- **Crash-class bug when committing from a panel arrow:** the arrow's own `pressed` signal refreshed the panel, which freed the still-emitting button ("Attempted to free a locked object"). It was found in the Android emulator's log; the tests had emitted the panel's signal instead of the button's. `MechanismPanel` now creates its 9 slot buttons once and reconfigures them in place.
- **Leave dialog had zero size** (seen on the emulator: top-left corner, no dimming, board still touchable). The cause was `set_anchors_preset`, which keeps offsets. It now uses `set_anchors_and_offsets_preset`, and the HUD containers were switched too.
- The arrow buttons' theme text padding no longer inflates collapsed panel rows.

**Verified on the Android emulator** (Compatibility-renderer diagnostic build)
- A real arrow tap pushes with no errors.
- Back closes the panel, then shows the centred, dimmed dialog.
- A tap behind the dialog is blocked, Stay closes it, and Back then Leave exits the app.

**Decisions:** P-010, slice softlocks accepted for now.

### 2026-11-15 — M4: Production solver and level validator

**Added**
- **`PuzzleSolver`** (`game/scripts/solver/`): exhaustive search over `PuzzleSimulator`, so it always agrees with gameplay.
  - `solve()` uses a layered search: core runs are free and mechanism actions cost 1, so it returns a solution with the proven minimum. It reports `limit_hit` instead of claiming "unsolvable" when capped.
  - `analyze()` is the softlock scan. It classifies every state within a given action depth as completable, a proven dead end (its whole closure has no completion) or unknown. Results are shared between closures, and it gives the shortest example path into a dead end.
- **`LevelValidator`**: the release gate from doc 08 and doc 12, with errors and warnings per P-008, plus a readable report.
- **`tools/validate_levels.sh`** (with `game/tools/validate_levels.gd`): validates every level in `game/data/levels`. Exit code 1 on any error. `tools/` is excluded from the Android export.
- `PuzzleAction.describe()` gives readable action names for reports.
- **Tests:** 14 solver and validator tests, bringing the suite to 144. They cover the minimum with free runs, proven unsolvability, honest limits, determinism, dead-end detection with its example path, unknown reporting, and every validator error and warning.

**Changed**
- `optimal_actions` is now set from proven minima: Level 1 = 0, slice = 4.
- The shipped-level test uses `PuzzleSolver` and requires `optimal_actions` to equal the proven minimum.

**Removed**
- `tests/support/test_solver.gd`, the test-only precursor, now replaced by `PuzzleSolver`.

**Validator findings** (slice, current layout; not changed, awaiting a design decision)
- 536 proven dead-end states within 5 actions, and 17 unknown.
- The shortest is `run > push block_a down > push block_a down > run`. Block A drops into the upper gravity zone on top of B, the column is full, and the gravity checkpoint allows nothing else.
- On a scratch copy, a wall at (3,2) removes that trap (232 dead ends left). The next shortest is pushing B out of its zone onto the route at the push checkpoint, a consequence of D-009.

**Known limitations**
- The full softlock scan takes about 40 s for the slice, so it lives in the validator rather than the test suite.
- No daily-schedule validation yet (no daily data exists).
- The "editor workflow" from doc 13 is the command-line validator only.

### 2026-11-15 — Android build and emulator check

**Added**
- `game/export_presets.cfg`: an "Android" debug preset. It builds arm64-v8a only, uses package `com.slideandseal.game` (a placeholder, see below), excludes `tests/*`, includes `data/*.json`, and enables immersive mode. It contains no keystore paths or passwords.

**Verified** (Pixel 8 emulator, Android 15, 1080×2400, arm64)
- The debug APK (≈28 MB) exports, signs, installs and launches. Level JSON is packaged and tests are excluded.
- Godot starts with Vulkan 1.3 and the Mobile renderer.
- **Using a throwaway Compatibility-renderer build** (made outside the repo, because of the emulator issue below):
  - The layout fits the tall screen. The top margin clears the 132px camera cutout, so the safe-area code works.
  - A real tap on Run moves the core to the first checkpoint.
  - A real tap on block A selects it and opens the panel, with the invalid direction disabled.
  - A real swipe pushes the block, and the HUD and panel update.

**Found**
- **Emulator only:** Vulkan frames never reach the screen ("Couldn't present to Vulkan queue", black screen). This happens both with the host GPU (via MoltenVK) and with SwiftShader. It is an emulator limitation, not a game bug; the same build renders under OpenGL. A real device is needed to verify the Mobile renderer.
- The default 2 GB emulator RAM was too little with software rendering, and the app was killed. Use `-memory 4096`.
- **Risk:** on a fresh emulator boot, an asset-paths configuration change (`Config changes=80000000`) recreated the activity during startup, and Godot quit instead of recovering. Watch for this on real devices.
- **To do:** Android Back quits the game immediately, mid-puzzle (Godot default). It needs a pause or confirm flow before release.
- **To do:** there is no project icon (export warning).

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
