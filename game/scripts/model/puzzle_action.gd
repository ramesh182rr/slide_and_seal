class_name PuzzleAction
extends RefCounted
## A player request to change puzzle state.

## RUN_CORE covers both "Run" and "Resume" (decision P-002).
## PUSH: target_id = object id (D-007). SET_GRAVITY: target_id = gravity zone id (D-006).
enum Kind { RUN_CORE, PUSH, SET_GRAVITY }

var kind: Kind = Kind.RUN_CORE
var target_id: String = ""
var direction: Grid.Direction = Grid.Direction.UP


static func run_core() -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = Kind.RUN_CORE
	return action


static func push(object_id: String, p_direction: Grid.Direction) -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = Kind.PUSH
	action.target_id = object_id
	action.direction = p_direction
	return action


static func set_gravity(zone_id: String, p_direction: Grid.Direction) -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = Kind.SET_GRAVITY
	action.target_id = zone_id
	action.direction = p_direction
	return action
