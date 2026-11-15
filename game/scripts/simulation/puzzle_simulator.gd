class_name PuzzleSimulator
extends RefCounted
## The single source of puzzle rules.
## Pure and deterministic: never mutates its inputs, uses no scene tree, physics, time or randomness.
## Gameplay, preview, hints, solver and validator must all go through these functions.


static func apply_action(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	match action.kind:
		PuzzleAction.Kind.RUN_CORE:
			return _run_core(level, state)
	return ActionResult.rejected(ActionResult.Failure.UNKNOWN_ACTION, "Unknown action kind %d." % action.kind)


## Preview is the real rule set without committing: identical to apply_action by construction.
## The returned state is a new object; the caller's state is never touched.
static func preview_action(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	return apply_action(level, state, action)


static func core_position(level: LevelDefinition, state: PuzzleState) -> Vector2i:
	return level.routes[state.core_route_id].nodes[state.core_node_index]


## A cell the core cannot enter.
static func is_cell_blocked(level: LevelDefinition, state: PuzzleState, cell: Vector2i) -> bool:
	return not level.in_bounds(cell) or level.is_wall(cell) or state.object_at(cell) != null


static func _run_core(level: LevelDefinition, state: PuzzleState) -> ActionResult:
	match state.phase:
		PuzzleState.Phase.SETUP, PuzzleState.Phase.CHECKPOINT_PAUSED, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION:
			pass
		_:
			return ActionResult.rejected(ActionResult.Failure.WRONG_PHASE,
				"The core cannot run in phase %s." % PuzzleState.Phase.keys()[state.phase])

	var route: RouteDefinition = level.routes[state.core_route_id]
	var index := state.core_node_index
	if index >= route.last_index():
		return ActionResult.rejected(ActionResult.Failure.WRONG_PHASE, "The core is already at the end of its route.")
	if is_cell_blocked(level, state, route.nodes[index + 1]):
		return ActionResult.rejected(ActionResult.Failure.ROUTE_BLOCKED,
			"The next route cell %s is blocked." % route.nodes[index + 1])

	var next := state.clone()
	next.core_run_count += 1
	var travel := CoreTravelResult.new()
	# Terminates: index strictly increases and the last route node is always the destination.
	while true:
		index += 1
		var cell := route.nodes[index]
		travel.path.append(cell)
		if index == route.last_index():
			next.phase = PuzzleState.Phase.LEVEL_COMPLETED
			travel.stop_reason = CoreTravelResult.StopReason.DESTINATION
			break
		var checkpoint := route.checkpoint_at(cell)
		if checkpoint != null:
			next.reached_checkpoint_ids.append(checkpoint.id)
			if checkpoint.auto_pause:
				next.phase = PuzzleState.Phase.CHECKPOINT_PAUSED
				travel.stop_reason = CoreTravelResult.StopReason.CHECKPOINT
				travel.checkpoint_id = checkpoint.id
				break
		var ahead := route.nodes[index + 1]
		if is_cell_blocked(level, state, ahead):
			next.phase = PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION
			travel.stop_reason = CoreTravelResult.StopReason.BLOCKED
			travel.blocked_cell = ahead
			break
	next.core_node_index = index
	return ActionResult.success(next, travel)
