# 08 — Level Design and Solver Specification

## 1. Level design principles

Every level should have one primary learning or reasoning objective. The board must visually communicate all relevant rules. Difficulty should come from planning and system interaction, not hidden mechanics.

## 2. Level acceptance checklist

- Objective is clear.
- All mechanisms are visually distinguishable.
- Initial state is valid.
- Every action has deterministic consequences.
- At least one solution exists.
- Solver and gameplay agree.
- No unintended softlocks.
- Checkpoints are authored intentionally.
- Undo/restart work.
- Target action count is justified.
- Human playtest confirms comprehension.

## 3. Solver state

Canonical solver state must include:
- Core position and route state.
- Current checkpoint/phase.
- Movable object positions.
- Gravity zones and directions.
- Portal active state/configuration.
- Switch/gate states.
- Rotating section orientations.
- Energy routing orientation/state.
- Magnetic polarity and field state.
- Objective progress.

If a field affects future behavior, it must be included in the state hash.

## 4. Search

Start with BFS for small, unit-cost action spaces. Consider A* only with an admissible heuristic. Use stable action ordering for reproducible solutions. Set explicit search limits and report when optimality cannot be proven.

## 5. Preview correctness

Preview must call the same resolver as committed gameplay. For every valid action, preview output should equal the committed result. Preview must not mutate live state.

## 6. Level data schema

See `14_Level_Data_Schema.md` and `data/levels/level_001_example.json`.

## 7. Campaign blueprint

A full 50-level title list and teaching objectives are in `09_50_Level_Campaign_Blueprint.md`.

## 8. Daily puzzle validation

Every daily puzzle must pass the same schema validator and solver. Store puzzle ID, UTC date key, mechanic focus, difficulty, validated solution metadata and publication status.
