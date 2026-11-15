class_name PuzzleAction
extends RefCounted
## A player request to change puzzle state. Mechanism actions are added per milestone.

## RUN_CORE covers both "Run" and "Resume" (decision P-002).
enum Kind { RUN_CORE }

var kind: Kind = Kind.RUN_CORE


static func run_core() -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = Kind.RUN_CORE
	return action
