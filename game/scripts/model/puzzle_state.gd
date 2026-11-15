class_name PuzzleState
extends RefCounted
## Complete puzzle-relevant runtime state.
## Committed instances are treated as immutable: the simulator always clones before changing anything.
## Every committed state is gravity-settled (D-006).

## CORE_TRAVELLING is not a committed phase: travel resolves atomically (decision P-001).
enum Phase { SETUP, CHECKPOINT_PAUSED, BLOCKED_WAITING_FOR_ACTION, LEVEL_COMPLETED }

var phase: Phase = Phase.SETUP
var core_route_id: String = ""
var core_node_index: int = 0
## Kept sorted by id (see sort_objects) so iteration and keys are deterministic.
var objects: Array[MovableObject] = []
## Current direction of each gravity zone, keyed by zone id.
var gravity_directions: Dictionary[String, Grid.Direction] = {}
## On/off state of each TOGGLE switch, keyed by switch id. (Pressure switches and gates are derived.)
var toggle_states: Dictionary[String, bool] = {}
## Clockwise quarter turns of each rotating section, 0–3 (D-020).
var section_turns: Dictionary[String, int] = {}
## True while the core travels a track piece from its last node towards its first (D-017).
var core_route_reversed: bool = false
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
	copy.gravity_directions = gravity_directions.duplicate()
	copy.toggle_states = toggle_states.duplicate()
	copy.section_turns = section_turns.duplicate()
	copy.core_route_reversed = core_route_reversed
	copy.reached_checkpoint_ids = reached_checkpoint_ids.duplicate()
	copy.mechanism_action_count = mechanism_action_count
	copy.core_run_count = core_run_count
	return copy


func object_at(cell: Vector2i) -> MovableObject:
	for obj: MovableObject in objects:
		if obj.position == cell:
			return obj
	return null


func object_by_id(object_id: String) -> MovableObject:
	for obj: MovableObject in objects:
		if obj.id == object_id:
			return obj
	return null


func sort_objects() -> void:
	objects.sort_custom(func(a: MovableObject, b: MovableObject) -> bool: return a.id < b.id)


## True when every object occupies the same cell in both states.
func has_same_object_positions(other: PuzzleState) -> bool:
	if objects.size() != other.objects.size():
		return false
	for i: int in objects.size():
		if objects[i].id != other.objects[i].id or objects[i].position != other.objects[i].position:
			return false
	return true


## Canonical serialization of every field. Two states are equal iff their keys are equal.
## Any new field that affects behaviour MUST be added here.
## `include_counters = false` drops the action/run counters, which do not affect future
## behaviour: equivalent boards then share a key (used by search).
func to_key(include_counters: bool = true) -> String:
	var object_parts := PackedStringArray()
	for obj: MovableObject in objects:
		object_parts.append("%s:%s@%d,%d%s%s" % [obj.id, obj.kind, obj.position.x, obj.position.y,
			"p" if obj.pushable else "", "g" if obj.gravity_affected else ""])
	var zone_ids: Array[String] = gravity_directions.keys()
	zone_ids.sort()
	var gravity_parts := PackedStringArray()
	for zone_id: String in zone_ids:
		gravity_parts.append("%s:%d" % [zone_id, gravity_directions[zone_id]])
	var toggle_ids: Array[String] = toggle_states.keys()
	toggle_ids.sort()
	var toggle_parts := PackedStringArray()
	for switch_id: String in toggle_ids:
		toggle_parts.append("%s:%d" % [switch_id, int(toggle_states[switch_id])])
	var section_ids: Array[String] = section_turns.keys()
	section_ids.sort()
	var section_parts := PackedStringArray()
	for section_id: String in section_ids:
		section_parts.append("%s:%d" % [section_id, section_turns[section_id]])
	var parts := PackedStringArray([
		"phase=%d" % phase,
		"core=%s#%d%s" % [core_route_id, core_node_index, "r" if core_route_reversed else ""],
		"sections=" + "|".join(section_parts),
		"objects=" + "|".join(object_parts),
		"gravity=" + "|".join(gravity_parts),
		"toggles=" + "|".join(toggle_parts),
		"checkpoints=" + "|".join(reached_checkpoint_ids),
	])
	if include_counters:
		parts.append("actions=%d" % mechanism_action_count)
		parts.append("runs=%d" % core_run_count)
	return ";".join(parts)
