class_name ActionResult
extends RefCounted
## Outcome of applying (or previewing) a PuzzleAction.
## On failure, `state` is null and the caller's state is untouched.

enum Failure { NONE, WRONG_PHASE, ROUTE_BLOCKED, UNKNOWN_ACTION }

var failure: Failure = Failure.NONE
var message: String = ""
## The resulting state when successful; null on failure.
var state: PuzzleState = null
## Set for RUN_CORE results.
var travel: CoreTravelResult = null


func is_ok() -> bool:
	return failure == Failure.NONE


static func success(p_state: PuzzleState, p_travel: CoreTravelResult = null) -> ActionResult:
	var result := ActionResult.new()
	result.state = p_state
	result.travel = p_travel
	return result


static func rejected(p_failure: Failure, p_message: String) -> ActionResult:
	var result := ActionResult.new()
	result.failure = p_failure
	result.message = p_message
	return result
