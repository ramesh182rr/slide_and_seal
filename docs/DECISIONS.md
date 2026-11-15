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
