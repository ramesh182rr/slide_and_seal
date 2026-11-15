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

### Approval of P-001 – P-006 (2026-11-15)
The project owner approved all provisional M1 choices below. They now carry the same weight as approved decisions.

---

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
