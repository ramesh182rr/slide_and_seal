class_name PuzzleState
extends RefCounted
## Complete puzzle-relevant runtime state.
## Committed instances are treated as immutable: the simulator always clones before changing anything.

## CORE_TRAVELLING is not a committed phase: travel resolves atomically (decision P-001).
enum Phase { SETUP, CHECKPOINT_PAUSED, BLOCKED_WAITING_FOR_ACTION, LEVEL_COMPLETED }

var phase: Phase = Phase.SETUP
var core_route_id: String = ""
var core_node_index: int = 0
## Kept sorted by id (see sort_objects) so iteration and keys are deterministic.
var objects: Array[MovableObject] = []
## Checkpoint ids in the order the core reached them.
var reached_checkpoint_ids: PackedStringArray = PackedStringArray()
## Player mechanism actions committed (excludes core runs).
var mechanism_action_count: int = 0
## Core travel segments committed.
var core_run_count: int = 0


func clone() -> PuzzleState:
	var copy := PuzzleState.new()
	copy.phase = phase
	copy.core_route_id = core_route_id
	copy.core_node_index = core_node_index
	for obj: MovableObject in objects:
		copy.objects.append(obj.clone())
	copy.reached_checkpoint_ids = reached_checkpoint_ids.duplicate()
	copy.mechanism_action_count = mechanism_action_count
	copy.core_run_count = core_run_count
	return copy


func object_at(cell: Vector2i) -> MovableObject:
	for obj: MovableObject in objects:
		if obj.position == cell:
			return obj
	return null


func sort_objects() -> void:
	objects.sort_custom(func(a: MovableObject, b: MovableObject) -> bool: return a.id < b.id)


## Canonical serialization of every field. Two states are equal iff their keys are equal.
## Any new field that affects behaviour MUST be added here.
func to_key() -> String:
	var object_parts := PackedStringArray()
	for obj: MovableObject in objects:
		object_parts.append("%s:%s@%d,%d" % [obj.id, obj.kind, obj.position.x, obj.position.y])
	var parts := PackedStringArray([
		"phase=%d" % phase,
		"core=%s#%d" % [core_route_id, core_node_index],
		"objects=" + "|".join(object_parts),
		"checkpoints=" + "|".join(reached_checkpoint_ids),
		"actions=%d" % mechanism_action_count,
		"runs=%d" % core_run_count,
	])
	return ";".join(parts)
