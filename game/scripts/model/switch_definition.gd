class_name SwitchDefinition
extends RefCounted
## An authored switch (decisions D-013, D-014). Immutable after loading.
## PRESSURE: on while a block rests on it (derived). TOGGLE: flipped by the player (stored state).
## RECEIVER: on while an energy beam reaches it (D-024; PuzzleState.powered_receivers, derived).

enum Kind { PRESSURE, TOGGLE, RECEIVER }

var id: String = ""
var kind: Kind = Kind.PRESSURE
var position: Vector2i = Vector2i.ZERO
## Starting state of a TOGGLE switch (PuzzleState.toggle_states).
var initially_on: bool = false
