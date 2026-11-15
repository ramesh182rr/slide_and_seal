# 02 — Core Gameplay and Checkpoint Specification

## 1. Board and coordinate model

The authoritative board is a rectangular discrete grid. Use integer coordinates with x increasing right and y increasing down. The 3D board renderer maps each cell coordinate to a world-space position.

Each cell may contain:
- Static terrain.
- One or more explicitly permitted mechanism fixtures.
- A movable object.
- The energy core.
- A checkpoint marker.
- A destination or objective marker.

Overlapping occupancy must be explicitly defined in level data. Do not infer it from visual mesh intersections.

## 2. Core movement model

The energy core follows a deterministic route through traversable cells. It does not require player steering at every cell.

The core travels between:
- The launch position.
- Authored interaction checkpoints.
- The destination.
- A blocking condition that requires a puzzle intervention.

The core pauses at authored checkpoints. The player can inspect and manipulate the environment without time pressure, then resume.

## 3. Checkpoint behavior

A checkpoint is a level-authored position or trigger region with an interaction policy.

Recommended checkpoint fields:
- `id`
- `position`
- `allowed_mechanisms`
- `auto_pause`
- `resume_condition`
- `hint_id` (optional)
- `camera_focus` (optional presentation hint)

At a checkpoint:
1. Core movement stops.
2. Core state is committed to the checkpoint cell.
3. Interaction UI becomes available.
4. Player may inspect and manipulate permitted mechanisms.
5. Preview may be requested.
6. Player chooses Resume.
7. The simulation calculates the next travel segment.

No timer begins at a checkpoint.

## 4. Movement and collision

Core movement should be cell-based and deterministic. A level must define how the core selects its next cell. Recommended initial rule: each traversable route cell has a defined connection or direction; intersections use explicit route logic or player-configured mechanism state. Do not rely on hidden random path selection.

If the next cell is blocked:
- Core pauses safely at the last valid cell.
- The level enters a `BLOCKED_WAITING_FOR_ACTION` state.
- Player can manipulate eligible mechanisms.
- Resume is available only when a valid route exists or the level explicitly permits a blocked attempt.

## 5. Run / pause / resume

- `RUN`: start core travel from launch or current checkpoint.
- `PAUSE`: available only at a safe cell or authored checkpoint, unless a level explicitly supports safe mid-segment pause.
- `RESUME`: continue from committed core position using current board state.
- `RESTART`: restore the initial puzzle state.
- `UNDO`: restore the previous committed player action or checkpoint state according to the level's undo policy.

## 6. Action phases

Recommended state machine:
- `SETUP`
- `CORE_TRAVELLING`
- `CHECKPOINT_PAUSED`
- `BLOCKED_WAITING_FOR_ACTION`
- `LEVEL_COMPLETED`
- `LEVEL_FAILED` (only if a future level has a defined failure condition)

Only allow mechanism actions in `SETUP`, `CHECKPOINT_PAUSED` or `BLOCKED_WAITING_FOR_ACTION`.

## 7. Player action transaction

Every mechanism action should:
1. Validate the selected mechanism and action.
2. Create a complete pre-action snapshot.
3. Calculate the result in the simulation layer.
4. Validate all occupancy and system constraints.
5. Commit the new state if valid.
6. Provide a preview/result summary.
7. Update the renderer and UI.

Invalid actions do not mutate state.

## 8. Preview

A preview shows the expected result of a selected action without committing it. It should include:
- Affected object positions.
- Gravity direction or rotation.
- Portal exit.
- Gate state changes.
- Energy beam path changes.
- Core's next travel segment where determinable.

Preview and actual simulation must call the same rule functions. Preview must not mutate the current state.

## 9. Undo and restart

Undo must restore all puzzle-relevant state:
- Core position and travel status.
- All movable object positions.
- Gravity direction and active zones.
- Portal configuration and state.
- Switch and gate states.
- Rotating section orientation.
- Magnetic polarity and charge.
- Energy routing state.
- Checkpoint state.
- Action counters and objective progress.

Restart restores the exact authored initial state.

## 10. Win condition

Default win condition: core reaches the destination and activates the final seal. Optional objectives may require additional conditions such as activating receivers or collecting energy nodes. The objective must be shown before play.
