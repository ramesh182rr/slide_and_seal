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

---

## Provisional (M1 implementation choices — please review)

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
