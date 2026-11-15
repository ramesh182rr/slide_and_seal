# Design & Technical Decision Log

Approved decisions override the open questions in
`Slide_and_Seal_Interactive_Labyrinth_v2/docs/18_Open_Design_Decisions.md`.
Entries are never silently rewritten. A decision that is later changed gets a new entry that references the old one.

Status values:
- **Approved:** confirmed by the project owner.
- **Provisional:** an implementation choice made within the approved design. It is flagged for review and may be changed on request.

---

## Approved

### D-001 — Vertical slice level content (2026-11-15)
The vertical slice is **one Awakening-themed level that includes gravity and push** (option b). This deliberately departs from the campaign teaching order for the slice only. The campaign blueprint is unchanged: campaign Level 1 "The First Signal" stays route/checkpoint-only, gravity is taught from Level 7 and push from Level 13.

### D-002 — Repository layout (2026-11-15)
The Godot project lives in `game/` (`game/project.godot`). The design package `Slide_and_Seal_Interactive_Labyrinth_v2/` stays untouched as read-only reference. Level data used by the game is **copied** into `game/data/`, not moved.

### D-003 — Core route model (2026-11-15; resolves doc 18 #1)
- The core follows an **explicitly authored route**, never pathfinding.
- Routes are stored as **segments**: ordered chains of orthogonally adjacent cells. Later, junctions between segments will be selected deterministically by mechanism state (portals, rotation, gates), never by search.
- When the next route cell is occupied by a movable object (or, later, a closed gate), the core stops on the last free cell and the phase becomes `BLOCKED_WAITING_FOR_ACTION`.
- Load-time rules:
  - nodes are in bounds and orthogonally adjacent
  - no walls on the route
  - no revisited cells
  - the core starts on the first node
  - the destination is the last node
  - checkpoints lie on the route but not on its first or last node
- Until junctions are implemented, a level has exactly one route segment.

### D-004 — Test framework (2026-11-15)
Use a small custom headless runner (`game/tests/run_tests.gd`), not GUT. Tests are plain `test_*` methods on classes extending `TestCase`. Engine and script errors raised during a test fail that test.

### D-005 — Orientation (2026-11-15; resolves doc 18 #10)
Portrait by default.

### D-006 — Gravity is a persistent field (2026-11-15; resolves doc 18 #3 for local zones)
- A gravity zone is a rectangle with a current direction (UP/RIGHT/DOWN/LEFT) and a list of directions the player may set.
- Every committed state is **settled**: gravity-affected objects inside a zone rest against the zone's direction.
- Settling runs after a gravity change, after a push, and **after every core step** during travel. A cell the core vacates can let a block slide into it.
- Objects slide cell by cell until stopped by the zone edge, a wall, another object or the core. The core is never moved by gravity.
- Resolution order: the object farthest along the gravity direction first, then by object id ascending. One pass is then exact.
- Initial level states must already be settled; the loader rejects them otherwise.
- Zones may not overlap.

### D-007 — Push Pulse (2026-11-15; resolves doc 18 #4)
- The player picks any object marked `pushable`, anywhere on the board, and a cardinal direction.
- It moves exactly one cell.
- The push is rejected if the target cell is out of bounds, a wall, another object (no chains) or the core's cell.
- Gravity then settles.
- A push whose net result changes no object position is rejected. For example, pushing against a zone's gravity when the block would fall straight back.

### D-008 — Mechanism availability (2026-11-15)
- **Before the first run (`SETUP`):** the level's `setup.allowed_mechanisms` apply.
- **Paused at a checkpoint:** that checkpoint's `allowed_mechanisms` apply.
- **While `BLOCKED_WAITING_FOR_ACTION`:** the list from the last checkpoint the core paused at applies, or the setup list if it has not paused yet.
- **After completion:** nothing is allowed.
- Every successful mechanism action increments the action counter. Rejected actions change nothing.

### D-009 — No per-checkpoint target scoping, for now (2026-11-15)
A checkpoint's `allowed_mechanisms` applies to **every** zone or object of that mechanism. Checkpoints cannot restrict which specific zones or blocks may be used. Consequence: a player may prepare a later beat early. In the slice, the lower zone can be flipped at the gravity checkpoint. This is accepted as valid play. Target scoping may be revisited once real campaign levels show a need; it would be a schema addition.

### D-010 — Vertical slice layout (2026-11-15)
`game/data/levels/world_01_slice.json`:
- 7×8 board.
- Three beats: push (A), gravity (B), and combined (F/E in a full column).
- Target: 4 mechanism actions.
- An exhaustive search showed every shortest solution follows the intended beats. Walls at (3,5), (0,7), (6,7) and (5,6) close the skips that search found.

### D-011 — Placeholder art first (2026-11-15)
M3 builds the 3D slice with simple primitive meshes in the doc 06 palette. It aims for correctness and readability. Premium meshes, materials, shaders and effects come in the polish stage.

### D-012 — Touch input: tap and swipe (2026-11-15)
Both are supported (built in M3b):
- **Tap:** tap a block or zone to select it (outline). A contextual panel then shows its valid directions, previews first and commits on confirm.
- **Swipe:** swipe starting on a block to push it in the swipe direction, or on a zone to set its gravity direction. Swipe is a shortcut; it goes through exactly the same action and validation path as the panel.

### D-013 — Gates never close on an occupied cell: reject the action (2026-11-15)
- A gate is open when **all** its linked switches are on. A closed gate blocks the core, pushes and gravity, like a wall.
- Any action whose resolved result would leave a closed gate on an occupied cell (a block or the core) is rejected, and the state is unchanged. This includes `RUN_CORE` when gravity during travel would release a switch.
- Gate state and pressure-switch state are derived from object positions and toggle states, never stored.
- Settling iterates until stable: gravity runs, gates are re-evaluated, and gravity runs again while anything moved.

### D-014 — Pressure switches are pressed by blocks only (2026-11-15)
The core passing over or resting on a switch does nothing. Toggle switches flip only through the player action `TOGGLE_SWITCH` (mechanism `switches_seals`).

### D-015 — Portals carry the core only, for now (2026-11-15)
Blocks treat portal cells as ordinary floor. Portal-compatible blocks may come later with a level that needs them.

### D-016 — Sequential unlocking (2026-11-15)
The first level in catalog order is always open. Completing a level unlocks the next one in catalog order, across worlds. Stars never gate progression (doc 01 §10).

### D-017 — Rotating sections turn track pieces; connection by adjacency (2026-11-15)
- A route segment lying wholly inside a rotating section is a **track piece**. It turns with the section and may be travelled in either direction.
- When the core reaches the open end of a fixed segment, it continues into a track piece only if one of the piece's (rotated) ends is orthogonally adjacent. It then leaves the piece's far end into the fixed segment that starts adjacent to it.
- If nothing lines up, the core waits (blocked) until the section is turned.
- Fixed segments connect to each other only through portals or track pieces.

### D-018 — Everything inside a section turns (2026-11-15)
- Walls and track pieces inside are stored at the authored orientation and derived for the current one. Blocks inside move with the section.
- A quarter turn is a one-to-one remap of the square, so nothing inside can collide.
- Sections must be square, at least 2×2, may not overlap each other or gravity zones.
- **First version:** switches, gates, portals, checkpoints, the core start and the destination may not lie inside a section.

### D-019 — No turning while the core is inside the section (2026-11-15)
A rotation is rejected (`MOVE_BLOCKED`) while the core is on any cell of the section.

### D-020 — Allowed turn directions per section (2026-11-15)
Each section lists `allowed_directions` from `clockwise` / `counterclockwise`. A rotation is one quarter turn and counts as one action. Rotation state is `PuzzleState.section_turns` (clockwise quarter turns, mod 4).

### D-021 — The core only enters a track piece it can pass straight through (2026-11-15; refines D-017)
At a junction, the core enters a track piece only if:
- its far end lines up with a corridor (a fixed segment starting adjacent to it), and
- every cell of the piece, plus that corridor's first cell, is free.

Otherwise the core waits **outside** the section, where it can still be turned. This removes the "stranded inside the turntable" class of softlock. D-019 stays as a safeguard. The owner approved "only enter when both ends connect"; the free-passage condition extends it, because a block on the piece or exit would otherwise strand the core the same way.

### D-022 — Reflectors are flipped by tapping (2026-11-15)
Reflectors are fixed two-sided mirrors oriented `/` or `\`. The player action `FLIP_REFLECTOR` (mechanism `energy_routing`) swaps the orientation and counts as one action.

### D-023 — Blocks stop beams (2026-11-15)
A beam stops before:
- a wall
- a closed gate
- a block
- another emitter
- the board edge

The core never interacts with beams.

### D-024 — Receivers are a switch kind (2026-11-15)
`kind: "receiver"` in `mechanisms.switches`. It is on while a beam reaches it, so gates, portals and emitters can `require` it. All gate rules apply, including never closing on an occupied cell.

### D-025 — Emitters may be switch-controlled (2026-11-15)
An emitter is always on unless it lists `requires` switches, which must then all be on.

### D-026 — Flipping a magnet fires a pulse (2026-11-15)
The player action `FLIP_MAGNET` (mechanism `magnetic_polarity`) switches a magnet between + and −. It then immediately resolves one pulse with the new polarity, and counts as one action.

### D-027 — Pulse reach and movement (2026-11-15)
- The pulse travels along the magnet's row and column in all four directions until a wall, closed gate, solid fixture or the board edge.
- In each line only the **first block** is affected; it shields everything behind it. A neutral block just shields.
- A polarised block moves **one cell**: toward the magnet if the polarity is opposite, away if it matches. It moves only if that cell is free (in bounds, not a wall or solid fixture, no block, not the core, not a closed gate). Otherwise it stays.
- The four lines never share cells, so the moves cannot conflict. Gravity then settles, and the gate rules apply.

### D-028 — Pulse only, no continuous force (2026-11-15; doc 18 #7)
Magnets act only at the moment they are flipped. Blocks moved later are not pulled back.

### D-029 — Only blocks are magnetic (2026-11-15)
Blocks may carry `polarity` `+` or `-` (unmarked = neutral). The core never reacts to magnets, and the field passes over the core's cell.

### D-030 — Campaign production approach (2026-11-15)
- **Demo levels:** the three demo levels matching doc 09 briefs keep those campaign slots: "Reflector Logic" (#28), "Quarter Turn" (#32) and "Opposite Attraction" (#34). The vertical slice and the switches/portals showcase are retired from the catalog; their files live in `game/data/levels/retired/` for tests and reference, outside the catalog, validator and shipped-level tests.
- **World 1:** keeps doc 09's six teaching beats, with small decisions added where possible.
- **Review flow:** one world at a time. Each level is proven by the validator (solvable, proven minimum, softlock scan) and screenshotted before owner review.

### D-031 — Free view rotation (2026-11-15)
The player can rotate the board **view** to any angle around the board centre. This is presentation only: it never changes the puzzle, and it is unrelated to the rotating-section mechanic. Arrow panels, swipes and picking follow the live camera projection.

### D-032 — View controls: gestures plus buttons (2026-11-15)
- **Gestures:** pinch to zoom, two-finger drag to pan, two-finger twist to rotate (free).
- **Buttons:** on-screen rotate left/right (animated 90° steps), zoom in/out and reset view.
- **Desktop:** mouse wheel zooms, Q/E rotate, R resets.

### D-033 — Redesign Worlds 1–2 to a richer standard (2026-11-15)
- Owner feedback: the drafted levels felt too simple, with too few interactions.
- **New standard:**
  - every level has a named hook
  - boards grow through each world
  - several checkpoints or decision points
  - rising difficulty within a world
- Worlds 1 and 2 are redone before World 3.

### D-034 — World 1 teaches levers and gates (2026-11-15; changes the doc 07/09 teaching order)
- World 1 levels 1–2 stay gentle route/checkpoint introductions. The rest teach levers and gates in depth: symbols, multi-lever gates, lever order across checkpoints, and gates never closing on the core.
- World 5 then focuses on pressure plates and energy.

### D-035 — Inverted gates (2026-11-15)
- A gate may be marked `inverted`. It is the exact opposite of a normal gate with the same switches: **closed while all its switches are on, open otherwise**.
- Why: with normal gates only, switching a lever on can never hurt, so every lever level has one trivial answer ("turn on the right levers"). Inverted gates make one lever open one gate and close another, so the order of lever moves across checkpoints matters (D-034).
- All existing rules apply unchanged:
  - a closed gate blocks the core, pushes and gravity
  - no action may close a gate on the core or a block
- **Presentation:** inverted gates are pink instead of amber, and their symbol carries a "¬" (e.g. "¬C"), so the difference reads without colour. A lever's label lists every gate it affects (e.g. "A ¬C").

### Approval of P-001 – P-006 (2026-11-15)
The project owner approved all provisional M1 choices below. They now carry the same weight as approved decisions.

---

## Provisional (M3b implementation choices — please review)

### P-007 — How "preview, then confirm" works on touch (implements D-012)
- **Panel:** pressing and holding an arrow shows the preview (ghost blocks at their resulting cells). Releasing on the arrow commits; dragging off cancels. The hold is the preview and the release is the confirm, so there is no separate Confirm button.
- **Swipe:** once a drag passes 60 viewport px, the preview for that direction appears. Releasing commits. Dragging back inside the threshold cancels, and a short drag counts as a tap.
- **Arrow layout:** arrows are drawn and placed by their **on-screen** direction. In the isometric view, grid "up" is drawn up-right. Swipe direction is classified against the same camera projection.
- **Selection:** a block takes priority over the zone beneath it. The selection stays after a commit for follow-up moves. It is dropped when the context no longer allows its mechanism.

### P-008 — Level validation policy (M4)
- **Errors** (block shipping):
  - schema errors
  - unsolvable, or no solution found within the search limit
  - `target_actions` below the proven minimum
  - `optimal_actions` set but different from the proven minimum
- **Warnings** (designer decision):
  - `optimal_actions` null
  - proven dead-end states (softlocks). Undo always recovers, and doc 08 asks for no *unintended* softlocks, so a designer decides.
  - states the scan could not classify
- **Softlock scan scope:** every state reachable within *(proven minimum + 1)* mechanism actions. A state is a dead end only when its whole closure is exhausted without a completion (cap 4,000 states per closure). Undecided states are reported as unknown, never guessed.
- `optimal_actions` is filled in only from the solver's proven minimum.

### P-009 — Android Back / Escape
Godot's `quit_on_go_back` is off. Back unwinds one layer at a time: it closes the leave dialog, then closes the mechanism panel, then asks "Leave this puzzle?" (Stay / Leave). There is no "press again within N seconds" pattern, since that would be a timer. Until menus exist, Leave quits the app; later it will return to level select.

### P-010 — Slice softlocks accepted for now
The validator's dead ends in the slice (see the M4 changelog) are accepted for the vertical slice: undo always recovers. Revisit together with D-009 (per-checkpoint target scoping) when campaign levels are designed.

### P-011 — Presenting switches, gates and portals (M5c)
- **Link symbols** (shape and text, not colour alone, per doc 05 §4):
  - gates get letters (A, B, … by id)
  - each entry/exit portal pair gets a number (1, 2, …)
  - every switch shows the symbols of everything it powers ("A", "1", or "A 1")
- **Visuals:**
  - closed gates stand on their cell; open gates sink to a flat plate
  - switch lamps and pressure plates glow mint when on
  - portals glow violet when active, and entries carry a swirl disc
- **Interaction:**
  - Toggle switches are **tap-only**: the panel shows one "Switch on/off" button, hold to preview, release to commit.
  - Pressure plates, gates and portals are not player-operated; tapping one explains what powers it.
  - Tap priority: block, then switch, gate, portal, zone.
- **Preview:** a gate that would close shows a raised ghost; a gate that would open shows a glowing shell.
- **Development:** `godot --path game -- --level=<id>` loads another level until menus exist.

### P-012 — Menu skeleton and navigation
- `AppRoot` is the main scene and owns one screen at a time: Home → Level select → Gameplay.
- **Level order and world grouping** come from `game/data/catalog.json`, not from file names. Every level file must be listed (a test enforces it), and every entry is loaded through `LevelLoader`.
- **All levels are open** until save data and unlocking exist.
- **Completion card:** after the completing travel plays back, it shows actions against the target, plus "Level select" and "Next level" (hidden on the last level). Undo hides it again.
- **Back / Escape:** gameplay handles its own (P-009), and Leave there returns to level select. Level select → Home; Home → exit app.
- Placeholder screens built in code with the shared `UiTheme`. The doc 06 world-select dioramas, splash and store come later.

### P-013 — Progress, save data and stars
- **Saved per level:** completed, and best mechanism actions (fewest across completions).
- **Save file:** `user://progress.json` with `schema_version` 1. Writes go to `.tmp`, the previous save is copied to `.bak`, then the temp file is renamed into place. On load, an unreadable or unsupported file is renamed `.corrupt` (never deleted), then the backup is tried, then progress starts empty.
- **Stars** follow doc 01 §10, computed from the best result:
  - 1 for completing
  - 2 for meeting `target_actions`
  - 3 for matching the solver-proven `optimal_actions` (never awarded when no optimum is recorded)
- **Completion card:** shows the stars for this run and "New best!" on the first completion or an improvement.
- **Tests never touch the real save:** they use `user://test_*.json` scratch files cleaned in `after_each()`, and `TestFiles.remove_progress` refuses the real path.

### P-014 — Presenting rotating sections (M6b)
- **Visuals:**
  - Each section is a pivot carrying its floor tiles (slightly lighter), walls and track inlay, turned to the current orientation.
  - A fixed amber square frame outlines it (cyan when selected), and an off-centre hub shows the turn.
- **Playback:** the platform turns over 0.4 s, and blocks on it orbit the centre in step. Gravity and gate changes play afterwards.
- **Interaction:**
  - Tap any section cell without a block to select the section.
  - The panel shows one button per allowed direction ("Turn clockwise" / "Turn counter-clockwise"), with hold to preview and release to turn.
  - The preview shows where the track pieces will lie and where blocks will land.
  - Sections are tap-only, like switches.
- Fixed (non-pushable) blocks are drawn grey steel, to stand apart from walls and pushable blocks.

The "stranded inside a section" softlock raised here was resolved by D-021.

### P-015 — Energy routing details (M7a)
- **Beams:**
  - Receivers **absorb** the beam: it stops on the first receiver it reaches.
  - Beams pass over route cells, portals and pressure/toggle switches.
  - Each (cell, direction) is visited at most once, so a beam can never loop.
- **Emitters and reflectors are solid** for blocks and the core (like walls). They may not sit on a route, share a cell with another fixture, or lie inside a rotating section (first version).
- **Power is derived:** computed from "nothing powered" upward until stable. More power only opens gates or starts emitters, which only extends beams, so it always settles. It is re-evaluated inside every settle pass (so gravity moving a block into a beam takes effect) and is excluded from the state key, since it follows from the rest.

### P-016 — Presenting energy routing (M7b)
- **Visuals:**
  - Emitters are a block with a glowing nozzle facing the firing direction.
  - Mirrors are a slab on a base, turned to `/` or `\`. They swing when flipped.
  - Receivers are a pedestal with a crystal lamp that glows mint when powered.
- **Beams** are glowing cyan lines rebuilt from `EnergyResolver.trace` after every committed state. A beam stopped by an obstacle shows a short stub reaching its face.
- **Preview:** flipping previews the new beam path as a mint ghost, plus gate ghosts.
- **Interaction:**
  - Mirrors are tap-only: the panel shows "Flip mirror", hold to preview and release to flip.
  - Tapping a receiver or emitter explains it.
  - The panel title avoids `/` and `\`, because grid diagonals look horizontal or vertical in the isometric view.

### P-017 — Magnetic polarity details (M8a)
- **Magnets are solid fixtures**, like emitters and reflectors: never on a route, never sharing a cell, never inside a rotating section (first version). They also stop energy beams.
- **A flip always succeeds**, even if no block moves: the polarity changes, which matters for the next pulse.
- **Order of a flip:** the pulse resolves first, then gravity settles and gates are re-evaluated. A result that would close a gate on something is rejected as usual.
- Blocks keep their polarity when pushed, dropped or turned with a section.

### P-018 — Presenting magnetic polarity (M8b)
- **Polarity is always shown by colour and symbol** (doc 05 §4): + is red, − is blue (doc 06 palette).
  - Magnets have a coloured cap and a large billboard symbol.
  - Polarised blocks have a coloured band and a symbol.
  - The display uses the true minus sign U+2212, which the built-in Open Sans renders as wide as "+"; a hyphen read as a dot. Level data keeps ASCII `+` / `-`.
- **Interaction:**
  - Tap a magnet for a panel titled "Magnet (+)" with a "Switch to −" button (hold to preview, release to flip). The hint states which blocks will be attracted and which repelled.
  - Tapping a polarised block that cannot be pushed explains how magnets act on it.
- **Playback:** blocks moved by one pulse move together.
- **Labels:** switch and portal labels sit above block height, so a block resting on them never collides with its own label.

### P-019 — Settings screen
- Home → Settings has only settings that work today:
  - **Reduced motion**, which plays every committed result instantly (doc 01 §12)
  - **Reset progress**, behind a "Reset all progress?" confirmation; settings are kept
- Sound, haptics, UI scale and high contrast will be added together with those features, never as dead switches.
- Settings are saved to `user://settings.json` (schema 1) through the shared crash-safe `SafeJsonFile`, the same as progress.
- The toggle shows "On"/"Off" in text, since the default switch icon is unreadably small.
- Back closes the confirmation first, then returns home.

### P-020 — World 1 "The Awakening" design (superseded by P-023 on 2026-11-15)
- **Levels 1–4 have no mechanisms:** route, core and seal (1); reading a winding route (2); first checkpoint (3); two checkpoints (4).
- **No decisions are possible without a mechanism** (a level with none offers only Run), so "small decisions" start where doc 09 itself asks for an interaction: #5 "Resume after a simple interaction".
  - Levels 5 and 6 use a lever opening a gate. This introduces the toggle switch in World 1, earlier than doc 03's teaching order (switches in World 5), as the simplest possible interaction.
  - Level 6 adds a reading choice: of two levers at the second checkpoint, only the one whose symbol matches the gate on the route helps; the other opens a gate off the route.
- Proven minimums are 0, 0, 0, 0, 1 and 2, with 0 dead ends in all six.
- Level 6's decoy gate was moved off the route after a screenshot showed that, in the isometric view, it appeared to sit on the path.

### P-021 — World 2 "Gravity Works" design (superseded by P-024 on 2026-11-15)
- **Gravity-only puzzles** (doc 09 #7–12). Gravity never moves a block out of its zone, so each level is built around one real gravity decision:
  - drop (7)
  - flip a stacked pair (8)
  - choose the clearing direction in a sideways field (9)
  - two zones at two checkpoints (10)
  - one column crossed twice, so the block must be dropped, then lifted (11)
  - mastery over three checkpoints (12)
- Proven minimums are 1, 1, 1, 2, 2 and 3, with 0 dead ends in all six.
- Blocks are non-pushable (push is World 3).
- Known art gap: these blocks are drawn as grey "fixed" steel, with no visual cue yet for "affected by gravity".

### P-022 — View control details (M9a, implements D-031 / D-032)
- **Gestures:** a second finger turns any touch into a view gesture: pinch zooms, twist rotates freely (the board follows the fingers), and the midpoint drag pans.
  - A swipe preview in progress is cancelled.
  - No tap or swipe fires until every finger is lifted, so ending a gesture never selects or pushes anything.
- **Buttons:** a slim column on the right edge (rotate counter-clockwise, rotate clockwise, zoom in, zoom out, reset). Turns are 90° and animate over 0.3 s; reduced motion makes them instant. Each zoom step is ×1.25.
- **Limits:** zoom 1× (the whole board fits) to 3×. Panning stops when the view centre reaches the board's edge, so the board can never be lost off screen. Reset restores the default 45° view, 1× zoom and no pan.
- **View changes work during move playback** (they are presentation only). The arrow pad and swipe directions update live.
- **Desktop:** the mouse wheel zooms ×1.1, Q/E turn the view, R resets, and trackpad pinch and scroll zoom and pan.
- The view is not saved; each level opens at the default view.

### P-023 — World 1 "The Awakening" redesign (M10, awaiting review; implements D-033, D-034, D-035)
- **Boards grow** through the world: 7×9, 8×8, 8×9, 9×10, 10×9 and 11×11. Every level has two to four checkpoints.
- **Hooks**, one per level:
  1. The First Signal: route, core and seal, and the first pause.
  2. Dormant Path: three checkpoints on a long winding route.
  3. Lever and Gate: one lever per gate, at two checkpoints, plus a decoy lever whose gate is off the route.
  4. Two Keys: gates that need two levers, one lever already on, and a decoy.
  5. Opposite Doors: inverted gates. A lever opens one gate and closes another, and the core can wait in front of a closed gate while you change the levers.
  6. The Awakening: three levers and nine gates over four checkpoints, one of them on a gate (it cannot close under the core). The best line needs the core to wait on an inverted gate.
- **Proven minimums:** 0, 0, 2, 3, 5 and 8, with 0 dead ends in all six.
- **Scoring:** targets are the minimum for minimums up to 2, minimum + 1 for 3–5, and minimum + 2 from 6.

### P-024 — World 2 "Gravity Works" redesign (M10, awaiting review; implements D-033)
- **Boards grow** through the world: 8×8 up to 11×13. Gravity is combined with the levers and gates taught in World 1.
- **Hooks**, one per level:
  7. Downward Pull: one block blocks the route twice, above and below.
  8. Shift the Weight: two fields (a column and a row) over four checkpoints.
  9. Sideways Field: a tilt chamber with inner walls. The obvious tilt traps a block; the answer is left, then down, then up.
  10. Held by Gates: closed gates hold blocks up a shaft, and opening one lets a block move past it. One lever is a decoy.
  11. Stable Position: two shafts, one pulling up and one down, each split by a gate, over four checkpoints.
  12. Gravity Works: a tilt chamber and a gated shaft. Lever A frees the shaft, but it also closes an inverted gate on the last row, so it must be switched off again.
- **Proven minimums:** 2, 4, 3, 3, 3 and 5, with 0 dead ends in all six.
- To keep the solver fast, the chamber in level 12 allows up, down and left only. A fourth direction added nothing to the solution and made validation take over a minute.
- Known art gap (from P-021): gravity blocks still look like fixed steel.

### P-025 — On-screen Back in gameplay
- A **Back** button sits at the top left of the gameplay HUD, as on Level select and Settings.
- Unfinished level: it asks "Leave this puzzle?" straight away, closing any open panel behind the dialog. Finished level: it leaves at once, since the result is already saved.
- The system Back keeps its layered unwinding (P-009).

## Provisional (M1 implementation choices — approved 2026-11-15)

### P-001 — Core travel resolves atomically
A Run/Resume computes the whole travel segment in one simulation transition. `CORE_TRAVELLING` is therefore a presentation/controller phase (introduced with the 3D slice, during which input is locked), not a committed simulation phase. `LEVEL_FAILED` is omitted until a level defines a failure condition.

### P-002 — Run and Resume are one simulation action
`RUN_CORE` is valid in `SETUP`, `CHECKPOINT_PAUSED` and `BLOCKED_WAITING_FOR_ACTION`. The UI may label it "Run" or "Resume"; the rule is identical.

### P-003 — A run into an immediately blocked cell is rejected
If the very next route cell is blocked, `RUN_CORE` is rejected and state is unchanged (doc 02 §4: resume only when a valid route exists). `BLOCKED_WAITING_FOR_ACTION` therefore only arises when the core is stopped mid-segment.

### P-004 — Checkpoint semantics
A checkpoint triggers when the core **enters** its cell. A checkpoint with `auto_pause: false` is recorded as reached but does not stop the core. If a checkpoint cell is followed by a blocked cell, the core pauses at the checkpoint (phase `CHECKPOINT_PAUSED`).

### P-005 — Undo and restart (resolves doc 18 #9 provisionally)
- Undo covers every committed action, **including core travel segments**.
- Restart restores the exact authored initial state and is **itself undoable**.
- Restart while already in the initial state does nothing.
- Undo history is unbounded for now; states are small.

### P-006 — Level schema v3
The schema changes from the package example (v2) are documented in `docs/LEVEL_SCHEMA.md`.
