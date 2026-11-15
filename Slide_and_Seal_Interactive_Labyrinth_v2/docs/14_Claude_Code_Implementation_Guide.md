# 14 — Claude Code Implementation Guide

You are implementing Slide & Seal, a Godot 4.x Android-first hybrid 2D/3D interactive mechanical puzzle.

## Mandatory context

Read all Markdown documents in `docs/` before implementation. The Master GDD, Core Gameplay and Mechanics Bible define the intended product.

## Non-negotiable rules

1. Do not resurrect the previous automatic one-step-per-player-move gameplay.
2. Core travels along a deterministic route and pauses at authored checkpoints.
3. No countdowns or reaction-time requirements.
4. Simulation is discrete 2D grid logic.
5. 3D nodes render simulation state; they do not own game rules.
6. Use typed GDScript.
7. Use one resolver for gameplay, preview, hints, solver and validation.
8. Animation never changes puzzle state.
9. Do not implement monetization before the core vertical slice is stable.
10. Do not invent ambiguous mechanics silently. Record a design decision and ask for approval when it affects gameplay.

## Implementation stages

### Stage 1 — Data model
Create typed classes/resources for LevelDefinition, PuzzleState, MechanismState, CoreState, CheckpointDefinition, PuzzleAction and ActionResult.

### Stage 2 — Grid and collision
Implement coordinates, terrain, occupancy, bounds and stable IDs.

### Stage 3 — Gravity and push
Implement deterministic gravity settling and one-cell push. Add tests before visuals.

### Stage 4 — Core route and checkpoints
Implement run, travel segment, checkpoint pause, blocked wait, resume and completion. No timer logic.

### Stage 5 — 3D vertical slice
Create one isometric board, core, mechanisms, camera and 2D HUD. Ensure visual state matches model state.

### Stage 6 — Preview and undo
Preview must not mutate state and must match actual committed result. Undo restores all puzzle state.

### Stage 7 — Portals and switches
Implement paired portal transport and switch/gate conditions.

### Stage 8 — Advanced mechanics
Implement rotating sections, energy routing and magnetic polarity with unit tests.

### Stage 9 — Solver and content
Implement canonical state keys, BFS initially, level validator and JSON loading.

### Stage 10 — Campaign and daily
Build world/level selection, campaign progression and pre-authored daily schedule.

### Stage 11 — Polish
High-end UI, shaders, materials, effects, sound, accessibility and Android optimization.

### Stage 12 — Monetization
Integrate billing and rewarded ads behind service interfaces after the core experience is stable.

## After every stage, report

- Files created/changed.
- Design decisions made.
- Tests added.
- Tests actually run and results.
- Known limitations.
- Next stage proposal.

Never claim tests passed unless they were run. Never replace a design decision without documenting it.
