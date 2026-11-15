# Level Data Schema — v3

This document stands in for the `14_Level_Data_Schema.md` that the design package references but does not include.
The loader is `game/scripts/simulation/level_loader.gd`. Any validation error rejects the whole level; no partial level is ever loaded.

## Conventions
- A cell is a pair `[x, y]` of integers. x increases to the right and y increases downward. Integral JSON numbers such as `3.0` are accepted; `3.5` is rejected.
- IDs are non-empty strings and must be unique within their category.

## Top level

| Key | Type | Required | Notes |
|---|---|---|---|
| `schema_version` | int | yes | Must be `3`. |
| `id`, `title`, `world_id` | string | yes | |
| `access` | `"free"` \| `"premium"` | yes | |
| `board` | `{width, height}` | yes | Each side 1–32. |
| `core` | `{position, route_id}` | yes | `position` must equal the first node of `route_id`. |
| `destination` | `{position, seal_id}` | yes | `position` must equal the last node of the start route. |
| `terrain` | `{walls: [cell]}` | yes | `walls` optional, unique, in bounds. |
| `routes` | `{route_id: Route}` | yes | Exactly one segment until junctions exist (D-003). |
| `objects` | `[Object]` | no | Movable objects. |
| `mechanisms` | `{collection: []}` | no | Every collection must be empty until its resolver exists. |
| `objectives` | `[Objective]` | yes | Only `reach_destination` is supported. |
| `scoring` | `{target_actions, optimal_actions}` | yes | `optimal_actions` is `null` unless proven by the solver. |

### Route
```json
{ "nodes": [[0,3],[1,3]], "checkpoints": [Checkpoint] }
```
Route rules:
- nodes are in bounds and orthogonally adjacent
- no walls on the route
- no revisited cells
- at least 2 nodes

### Checkpoint
```json
{ "id": "checkpoint_01", "position": [3,3], "auto_pause": true, "allowed_mechanisms": [] }
```
- `position` must be on the route, but not on its first or last node.
- `auto_pause` defaults to `true`.
- `allowed_mechanisms` values: `gravity_shift`, `push_pulse`, `portal_network`, `switches_seals`, `rotating_sections`, `energy_routing`, `magnetic_polarity`.

### Object
```json
{ "id": "block_a", "kind": "block", "position": [2,3] }
```
Object rules:
- `kind` is currently `block`.
- in bounds, not on a wall
- no two objects on one cell
- not on the core's start cell

An object on a route cell blocks the core (D-003).

### Mechanism collections
`gravity_zones`, `push_devices`, `portals`, `switches`, `gates`, `rotating_sections`, `energy_emitters`, `reflectors`, `receivers`, `magnetic_fields`, `magnetic_objects`.

## Changes from the package example (v2 → v3)
- Removed `core.status`. It is runtime state and belongs in `PuzzleState`, not in level data.
- Removed `terrain.walkable`. Its meaning was undefined; every non-wall cell is a board cell. Floor/void presentation will be specified with the 3D board.
- Added top-level `objects` for movable objects.
- Unknown mechanism collections and non-empty, unsupported ones are now load errors, not silently ignored.
