# 03 — Mechanics Bible: Rules, Interactions and Teaching

This document proposes the initial deterministic rule set. Prototype and playtest before treating every parameter as final.

## 1. Gravity Shift — signature mechanic

**Purpose:** change the direction of gravity in a defined zone.

Proposed rule:
- Gravity direction is one of UP, DOWN, LEFT or RIGHT.
- A gravity action applies to objects tagged as gravity-affected within the active zone.
- Objects settle cell-by-cell in the chosen direction until blocked by terrain, a closed gate, another object or a zone boundary.
- Resolve objects in a stable deterministic order.
- If multiple objects could interact, use a documented ordering rule such as farthest-along-gravity-first, then stable object ID.
- Core is not gravity-affected unless a level explicitly enables it.
- Gravity zones can be global or local; local zones are preferred for readable early puzzles.

Questions to validate:
- Can objects move through portal cells while settling? Default: no, portals only transport during core/object traversal if explicitly enabled.
- Can a block be crushed by a closing gate? Default: no; reject the action if it would create overlap.

## 2. Push Pulse

**Purpose:** move a selected compatible object or structure.

Proposed rule:
- Player selects an eligible object and a cardinal direction.
- Default push distance is one cell.
- Some authored push devices may move an object until the next obstruction, but this should be a separate clearly signposted mode.
- Push chains are disabled in the first prototype; later they may be enabled with deterministic farthest-first resolution.
- A push cannot create overlap or move objects outside their allowed region.

## 3. Portal Network

**Purpose:** connect separated maze regions.

Proposed rule:
- Portals have stable IDs and explicit pair IDs.
- A portal pair has an entry and exit orientation.
- The core or compatible objects are transported when entering an active portal.
- Exit cell must be valid and unoccupied.
- If exit is blocked, the entry portal behaves as blocked; do not teleport into overlap.
- Portal traversal consumes one route transition and does not create an extra movement step.
- Portal configuration may be fixed, switch-controlled or player-rotatable depending on level.

## 4. Switches and Seals

**Purpose:** create dependencies between board state and gate state.

Proposed rule:
- Pressure switches activate while a qualifying object occupies them.
- Toggle switches change state when explicitly activated.
- Energy receivers activate when a valid beam reaches them.
- Gates derive state from linked conditions.
- If a gate would close on an occupied cell, reject the action or keep the gate open according to the level's declared policy. Recommended default: reject the closing action.
- Gate logic must be deterministic and visible.

## 5. Rotating Sections

**Purpose:** rotate a bounded region of the maze by 90 degrees.

Proposed rule:
- A rotating section has a pivot, bounds, allowed directions and a list of entities/terrain that rotate with it.
- Rotation is a discrete quarter-turn, not free continuous rotation.
- Validate all resulting positions before committing.
- If an entity would collide or leave the section boundary, reject the action.
- Portals, beam emitters and checkpoints rotate only if their data says they belong to the section.
- Renderer animates rotation after the logical state is committed.

## 6. Energy Routing

**Purpose:** direct an energy beam through reflectors and receivers.

Proposed rule:
- Beam travels along grid directions.
- Reflectors have explicit orientation and deterministic reflection mappings.
- Beam stops at walls, closed gates or opaque objects.
- Beam can activate compatible receivers.
- Loops are detected using visited `(cell, direction, state)` tuples.
- Beam preview should show the full route and activation result.
- Energy routing is a puzzle subsystem, not a real-time physics simulation.

## 7. Magnetic Polarity

**Purpose:** attract or repel compatible components.

Proposed rule:
- Magnetic objects have a polarity tag: positive, negative or neutral.
- A field source has active polarity and a defined range/zone.
- Compatible opposite polarities attract; like polarities repel; neutral objects are unaffected unless specified.
- Movement occurs in deterministic grid steps with collision checks.
- Resolve only one declared magnetic pulse per action initially; avoid continuous force simulation.
- Magnetic movement should not create unpredictable chain reactions.

## 8. Energy Core

The core is a distinct geometric payload, not a character. It follows the level's route graph and pauses at authored checkpoints. Core travel is a deterministic state transition; 3D animation visualizes the result.

## 9. Interaction combinations

Examples:
- Gravity drops a block onto a pressure switch.
- Push moves a platform into alignment before section rotation.
- Portal transports the core to a distant route.
- Energy routing activates a remote gate.
- Polarity moves a metal component away from a corridor.
- Rotation changes portal adjacency.
- Switch activation powers a gravity reactor.

## 10. Teaching order

1. Maze route and core launch.
2. Gravity.
3. Push.
4. Portals.
5. Switches and gates.
6. Energy routing.
7. Rotating sections.
8. Magnetic polarity.
9. Multi-system combinations.

Each mechanic should have: visual introduction, safe demonstration, one focused puzzle, then a combination puzzle.
