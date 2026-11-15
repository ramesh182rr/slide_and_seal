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
| `core` | `{position, route_id}` | yes | `position` must equal the first node of `route_id` (the start segment). |
| `destination` | `{position, seal_id}` | yes | `position` must equal the last node of the final segment in the chain. |
| `terrain` | `{walls: [cell]}` | yes | `walls` optional, unique, in bounds. |
| `routes` | `{route_id: Route}` | yes | One or more segments, linked by portals or by track pieces in rotating sections (D-003, D-017). |
| `objects` | `[Object]` | no | Movable objects. |
| `setup` | `{allowed_mechanisms: [name]}` | no | Mechanisms usable before the first run (D-008). Defaults to none. |
| `mechanisms` | `{collection: []}` | no | `gravity_zones`, `switches`, `gates`, `portals` and `rotating_sections` are supported. Every other collection must be empty until its resolver exists. |
| `objectives` | `[Objective]` | yes | Only `reach_destination` is supported. |
| `scoring` | `{target_actions, optimal_actions}` | yes | Counts are mechanism actions (core runs are free). `optimal_actions` is `null` or the solver's proven minimum. `tools/validate_levels.sh` checks both. |

### Route
```json
{ "nodes": [[0,3],[1,3]], "checkpoints": [Checkpoint] }
```
Route rules:
- nodes are in bounds and orthogonally adjacent
- no walls on the route
- no cell appears twice, within a segment or across segments
- at least 2 nodes

Segments and connections (validated by the loader):
- A segment wholly inside a rotating section is a **track piece**. It turns with the section and may be travelled in either direction. A segment may not be partly inside a section. The start segment must be outside sections.
- The core starts on the first node of `core.route_id`.
- Each segment outside sections (a **fixed** segment) ends:
  - at the destination, or
  - on an **entry portal** (one with `exit`): the next segment starts on the exit portal's cell, or
  - next to exactly one rotating section: the core continues into whichever end of a track piece is currently adjacent, then from the piece's far end into the fixed segment that starts adjacent to it.
- Two fixed segments may not start next to the same section cell.
- Over every possible connection, the destination must be reachable, every segment must be reachable, and there must be no loops.

### Checkpoint
```json
{ "id": "checkpoint_01", "position": [3,3], "auto_pause": true, "allowed_mechanisms": [] }
```
- `position` must be on the route, but not on its first or last node.
- `auto_pause` defaults to `true`.

### Allowed mechanisms
These rules apply to both `setup.allowed_mechanisms` and checkpoint `allowed_mechanisms`:
- Known names: `gravity_shift`, `push_pulse`, `portal_network`, `switches_seals`, `rotating_sections`, `energy_routing`, `magnetic_polarity`.
- Only `gravity_shift`, `push_pulse`, `switches_seals` and `rotating_sections` are implemented. The others are rejected.
- No name may be listed twice.
- Allowing `gravity_shift` requires at least one gravity zone.
- Allowing `push_pulse` requires at least one pushable object.
- Allowing `switches_seals` requires at least one toggle switch. Pressure switches are not player-operated.

### Object
```json
{ "id": "block_a", "kind": "block", "position": [2,3], "pushable": true, "gravity_affected": true }
```
Object rules:
- `kind` is currently `block`.
- `pushable` and `gravity_affected` default to `true`.
- in bounds, not on a wall
- no two objects on one cell
- not on the core's start cell

An object on a route cell blocks the core (D-003). A non-gravity object inside a zone acts as a fixed obstacle.

### Gravity zone (`mechanisms.gravity_zones`)
```json
{ "id": "zone_upper", "position": [2,3], "size": [3,2], "direction": "down", "allowed_directions": ["up","down"] }
```
- `position` is the zone's top-left cell. The zone must have a positive size and lie inside the board.
- Zone ids are unique, and zones may not overlap.
- Directions are `up`, `right`, `down` or `left`. `allowed_directions` must be non-empty, contain no duplicates and include `direction`.
- The authored start state must already be at rest under gravity (D-006).

### Switch (`mechanisms.switches`)
```json
{ "id": "lever_a", "kind": "toggle", "position": [5,0], "initially_on": false }
{ "id": "plate_a", "kind": "pressure", "position": [2,2] }
```
- `kind` is `pressure` (on while a block rests on it; the core never presses it, D-014) or `toggle` (flipped by the player).
- `initially_on` (default `false`) applies to toggle switches only.
- In bounds, not on a wall, and at most one switch per cell.

### Gate (`mechanisms.gates`)
```json
{ "id": "gate_a", "position": [5,1], "requires": ["lever_a", "plate_a"] }
```
- The gate is open when **all** `requires` switches are on (D-013). A closed gate blocks the core, pushes and gravity.
- `requires` is non-empty, lists existing switch ids, and has no duplicates.
- In bounds, not on a wall, not on a switch, and at most one gate per cell.
- Switch and gate ids share one namespace.
- No gate may start closed on a block or on the core's start cell.

### Portal (`mechanisms.portals`)
```json
{ "id": "p_in", "position": [2,1], "exit": "p_out", "requires": ["lever_a"] }
{ "id": "p_out", "position": [4,1] }
```
- Portals carry the core only (D-015). Blocks treat portal cells as ordinary floor.
- `exit` (optional) names the portal the core arrives at; it must exist and not be the portal itself.
- `requires` (optional) lists switches that must all be on for the portal to work.
- When the core steps into an entry it continues from the exit cell in the same step, never resting on the entry. The entry counts as blocked if it is occupied, the portal is inactive, or the exit cell is blocked.
- On a route, a portal must be a segment's last node (an entry) or first node (an exit), never inside a segment.
- In bounds, not on a wall, switch or gate, and at most one portal per cell. Ids are unique among portals.
- `portal_network` has no player action yet, so it cannot be listed in `allowed_mechanisms`.

### Rotating section (`mechanisms.rotating_sections`)
```json
{ "id": "turntable", "position": [3,1], "size": 3, "allowed_directions": ["clockwise", "counterclockwise"] }
```
- A square of `size`×`size` cells (at least 2) with its top-left corner at `position`, inside the board. Sections may not overlap each other or gravity zones.
- Content is authored at turn 0. Walls, blocks and track pieces inside turn with it (D-018).
- `allowed_directions` is non-empty: `clockwise` and/or `counterclockwise`. One quarter turn per action. Turning is rejected while the core is inside (D-019).
- **Not supported inside a section yet:** switches, gates, portals, checkpoints, the core start, the destination.

### Mechanism collections
`gravity_zones`, `push_devices`, `portals`, `switches`, `gates`, `rotating_sections`, `energy_emitters`, `reflectors`, `receivers`, `magnetic_fields`, `magnetic_objects`.

## Changes from the package example (v2 → v3)
- Removed `core.status`. It is runtime state and belongs in `PuzzleState`, not in level data.
- Removed `terrain.walkable`. Its meaning was undefined; every non-wall cell is a board cell. Floor/void presentation will be specified with the 3D board.
- Added top-level `objects` for movable objects.
- Unknown mechanism collections and non-empty, unsupported ones are now load errors, not silently ignored.
- Added in M2 (backward compatible, so still v3): `setup`, the object flags `pushable` and `gravity_affected`, and `gravity_zones` content.
- Added in M5a (backward compatible): `switches` and `gates` content.
- Added in M5b (backward compatible): `portals` content and multiple route segments.
- Added in M6a (backward compatible): `rotating_sections` content and track pieces.
