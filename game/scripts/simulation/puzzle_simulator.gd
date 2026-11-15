class_name PuzzleSimulator
extends RefCounted
## The single source of puzzle rules.
## Pure and deterministic: never mutates its inputs, uses no scene tree, physics, time or randomness.
## Gameplay, preview, hints, solver and validator must all go through these functions.


static func apply_action(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	match action.kind:
		PuzzleAction.Kind.RUN_CORE:
			return _run_core(level, state)
		PuzzleAction.Kind.PUSH:
			return _push(level, state, action)
		PuzzleAction.Kind.SET_GRAVITY:
			return _set_gravity(level, state, action)
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


## Mechanisms the player may use in the current state (decision D-008).
static func allowed_mechanisms(level: LevelDefinition, state: PuzzleState) -> PackedStringArray:
	if state.phase == PuzzleState.Phase.LEVEL_COMPLETED:
		return PackedStringArray()
	# The last checkpoint the core paused at defines the context, both while paused and while blocked.
	for i: int in range(state.reached_checkpoint_ids.size() - 1, -1, -1):
		var checkpoint := level.checkpoint_by_id(state.reached_checkpoint_ids[i])
		if checkpoint.auto_pause:
			return checkpoint.allowed_mechanisms
	return level.setup_allowed_mechanisms


# --- Core travel --------------------------------------------------------------

static func _run_core(level: LevelDefinition, state: PuzzleState) -> ActionResult:
	if not _is_interactive_phase(state):
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
	var moves: Array[ObjectMove] = []
	# Terminates: index strictly increases and the last route node is always the destination.
	while true:
		index += 1
		next.core_node_index = index
		var cell := route.nodes[index]
		travel.path.append(cell)
		# Persistent gravity: the cell the core just vacated may let blocks slide (D-006).
		moves.append_array(GravityResolver.settle(level, next, cell, travel.path.size() - 1))
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
		if is_cell_blocked(level, next, ahead):
			next.phase = PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION
			travel.stop_reason = CoreTravelResult.StopReason.BLOCKED
			travel.blocked_cell = ahead
			break
	return ActionResult.success(next, travel, moves)


# --- Mechanism actions --------------------------------------------------------

static func _push(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	var rejection := _check_mechanism_available(level, state, MechanismIds.PUSH_PULSE)
	if rejection != null:
		return rejection
	var obj := state.object_by_id(action.target_id)
	if obj == null:
		return ActionResult.rejected(ActionResult.Failure.INVALID_TARGET, "No object '%s'." % action.target_id)
	if not obj.pushable:
		return ActionResult.rejected(ActionResult.Failure.INVALID_TARGET, "Object '%s' is not pushable." % obj.id)
	var core_cell := core_position(level, state)
	var target := obj.position + Grid.offset(action.direction)
	if not level.in_bounds(target) or level.is_wall(target) or target == core_cell or state.object_at(target) != null:
		return ActionResult.rejected(ActionResult.Failure.MOVE_BLOCKED,
			"Cannot push '%s' %s: %s is not free." % [obj.id, Grid.direction_name(action.direction), target])

	var next := state.clone()
	next.object_by_id(obj.id).position = target
	var moves: Array[ObjectMove] = [ObjectMove.new(obj.id, obj.position, target, ObjectMove.Cause.PUSH)]
	moves.append_array(GravityResolver.settle(level, next, core_cell))
	if next.has_same_object_positions(state):
		return ActionResult.rejected(ActionResult.Failure.NO_EFFECT,
			"Pushing '%s' %s has no effect: gravity returns it." % [obj.id, Grid.direction_name(action.direction)])
	next.mechanism_action_count += 1
	return ActionResult.success(next, null, moves)


static func _set_gravity(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	var rejection := _check_mechanism_available(level, state, MechanismIds.GRAVITY_SHIFT)
	if rejection != null:
		return rejection
	var zone := level.gravity_zone(action.target_id)
	if zone == null:
		return ActionResult.rejected(ActionResult.Failure.INVALID_TARGET, "No gravity zone '%s'." % action.target_id)
	if not zone.allowed_directions.has(action.direction):
		return ActionResult.rejected(ActionResult.Failure.INVALID_DIRECTION,
			"Gravity zone '%s' cannot point %s." % [zone.id, Grid.direction_name(action.direction)])
	if state.gravity_directions[zone.id] == action.direction:
		return ActionResult.rejected(ActionResult.Failure.NO_EFFECT,
			"Gravity zone '%s' already points %s." % [zone.id, Grid.direction_name(action.direction)])

	var next := state.clone()
	next.gravity_directions[zone.id] = action.direction
	var moves := GravityResolver.settle(level, next, core_position(level, state))
	next.mechanism_action_count += 1
	return ActionResult.success(next, null, moves)


static func _is_interactive_phase(state: PuzzleState) -> bool:
	return state.phase in [
		PuzzleState.Phase.SETUP,
		PuzzleState.Phase.CHECKPOINT_PAUSED,
		PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION,
	]


## Returns a rejection if `mechanism` may not be used now, or null if it may.
static func _check_mechanism_available(level: LevelDefinition, state: PuzzleState, mechanism: String) -> ActionResult:
	if not _is_interactive_phase(state):
		return ActionResult.rejected(ActionResult.Failure.WRONG_PHASE,
			"Mechanisms cannot be used in phase %s." % PuzzleState.Phase.keys()[state.phase])
	if not allowed_mechanisms(level, state).has(mechanism):
		return ActionResult.rejected(ActionResult.Failure.MECHANISM_NOT_ALLOWED,
			"%s is not available here." % mechanism)
	return null
