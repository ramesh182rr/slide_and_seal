class_name PuzzleAction
extends RefCounted
## A player request to change puzzle state.

## RUN_CORE covers both "Run" and "Resume" (decision P-002).
## PUSH: target_id = object id (D-007). SET_GRAVITY: target_id = gravity zone id (D-006).
## TOGGLE_SWITCH: target_id = toggle switch id (D-014); direction unused.
## ROTATE_SECTION: target_id = rotating section id; `clockwise` picks the turn (D-020).
## FLIP_REFLECTOR: target_id = reflector id (D-022).
enum Kind { RUN_CORE, PUSH, SET_GRAVITY, TOGGLE_SWITCH, ROTATE_SECTION, FLIP_REFLECTOR }

var kind: Kind = Kind.RUN_CORE
var target_id: String = ""
var direction: Grid.Direction = Grid.Direction.UP
var clockwise: bool = true


## Short human-readable form, e.g. "run", "push block_a up", "gravity zone_upper down".
func describe() -> String:
	match kind:
		Kind.PUSH:
			return "push %s %s" % [target_id, Grid.direction_name(direction)]
		Kind.SET_GRAVITY:
			return "gravity %s %s" % [target_id, Grid.direction_name(direction)]
		Kind.TOGGLE_SWITCH:
			return "toggle %s" % target_id
		Kind.ROTATE_SECTION:
			return "rotate %s %s" % [target_id, "cw" if clockwise else "ccw"]
		Kind.FLIP_REFLECTOR:
			return "flip %s" % target_id
	return "run"


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


static func toggle_switch(switch_id: String) -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = Kind.TOGGLE_SWITCH
	action.target_id = switch_id
	return action


static func rotate_section(section_id: String, p_clockwise: bool) -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = Kind.ROTATE_SECTION
	action.target_id = section_id
	action.clockwise = p_clockwise
	return action


static func flip_reflector(reflector_id: String) -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = Kind.FLIP_REFLECTOR
	action.target_id = reflector_id
	return action
