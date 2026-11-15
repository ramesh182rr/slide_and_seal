class_name ObjectMove
extends RefCounted
## One object displacement produced while resolving an action, for presentation.
## Gravity slides are reported as a single straight move from start to rest cell.

enum Cause { PUSH, GRAVITY, ROTATION }

var object_id: String
var from_cell: Vector2i
var to_cell: Vector2i
var cause: Cause
## During core travel: index into CoreTravelResult.path of the step that triggered the move.
## -1 for moves caused directly by a mechanism action.
var core_step: int


func _init(p_object_id: String, p_from: Vector2i, p_to: Vector2i, p_cause: Cause, p_core_step: int = -1) -> void:
	object_id = p_object_id
	from_cell = p_from
	to_cell = p_to
	cause = p_cause
	core_step = p_core_step
