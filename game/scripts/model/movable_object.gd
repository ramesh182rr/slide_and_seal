class_name MovableObject
extends RefCounted
## A movable board object, identified by a stable id. Pure data.

const KIND_BLOCK := "block"

var id: String
var kind: String
var position: Vector2i
## May be selected for Push Pulse (D-007).
var pushable: bool = true
## Settles inside gravity zones (D-006). Non-affected objects act as fixed obstacles there.
var gravity_affected: bool = true
## Magnetic polarity (D-029): +1, -1, or 0 for neutral.
var polarity: int = 0


func _init(p_id: String = "", p_kind: String = KIND_BLOCK, p_position: Vector2i = Vector2i.ZERO) -> void:
	id = p_id
	kind = p_kind
	position = p_position


func clone() -> MovableObject:
	var copy := MovableObject.new(id, kind, position)
	copy.pushable = pushable
	copy.gravity_affected = gravity_affected
	copy.polarity = polarity
	return copy
