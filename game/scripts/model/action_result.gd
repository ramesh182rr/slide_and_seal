class_name ActionResult
extends RefCounted
## Outcome of applying (or previewing) a PuzzleAction.
## On failure, `state` is null and the caller's state is untouched.

enum Failure {
	NONE,
	WRONG_PHASE,
	ROUTE_BLOCKED,
	UNKNOWN_ACTION,
	MECHANISM_NOT_ALLOWED,
	INVALID_TARGET,
	INVALID_DIRECTION,
	MOVE_BLOCKED,
	NO_EFFECT,
}

var failure: Failure = Failure.NONE
var message: String = ""
## The resulting state when successful; null on failure.
var state: PuzzleState = null
## Set for RUN_CORE results.
var travel: CoreTravelResult = null
## Object displacements in resolution order, for presentation.
var object_moves: Array[ObjectMove] = []


func is_ok() -> bool:
	return failure == Failure.NONE


static func success(p_state: PuzzleState, p_travel: CoreTravelResult = null,
		p_moves: Array[ObjectMove] = []) -> ActionResult:
	var result := ActionResult.new()
	result.state = p_state
	result.travel = p_travel
	result.object_moves = p_moves
	return result


static func rejected(p_failure: Failure, p_message: String) -> ActionResult:
	var result := ActionResult.new()
	result.failure = p_failure
	result.message = p_message
	return result
