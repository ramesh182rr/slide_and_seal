class_name MovableObject
extends RefCounted
## A movable board object, identified by a stable id. Pure data.

const KIND_BLOCK := "block"

var id: String
var kind: String
var position: Vector2i


func _init(p_id: String = "", p_kind: String = KIND_BLOCK, p_position: Vector2i = Vector2i.ZERO) -> void:
	id = p_id
	kind = p_kind
	position = p_position


func clone() -> MovableObject:
	return MovableObject.new(id, kind, position)
