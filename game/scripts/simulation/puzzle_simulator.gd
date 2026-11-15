class_name PuzzleSimulator
extends RefCounted
## The single source of puzzle rules.
## Pure and deterministic: never mutates its inputs, uses no scene tree, physics, time or randomness.
## Gameplay, preview, hints, solver and validator must all go through these functions.

## Safety bound for stabilize(); gravity only moves blocks forward, so real levels converge quickly.
const MAX_STABILIZE_PASSES := 64


static func apply_action(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	match action.kind:
		PuzzleAction.Kind.RUN_CORE:
			return _run_core(level, state)
		PuzzleAction.Kind.PUSH:
			return _push(level, state, action)
		PuzzleAction.Kind.SET_GRAVITY:
			return _set_gravity(level, state, action)
		PuzzleAction.Kind.TOGGLE_SWITCH:
			return _toggle_switch(level, state, action)
	return ActionResult.rejected(ActionResult.Failure.UNKNOWN_ACTION, "Unknown action kind %d." % action.kind)


## Preview is the real rule set without committing: identical to apply_action by construction.
## The returned state is a new object; the caller's state is never touched.
static func preview_action(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	return apply_action(level, state, action)


static func core_position(level: LevelDefinition, state: PuzzleState) -> Vector2i:
	return level.routes[state.core_route_id].nodes[state.core_node_index]


## A cell the core cannot enter.
static func is_cell_blocked(level: LevelDefinition, state: PuzzleState, cell: Vector2i) -> bool:
	return not level.in_bounds(cell) or level.is_wall(cell) or state.object_at(cell) != null \
		or SwitchGateResolver.is_closed_gate_at(level, state, cell)


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


## Brings `state` to rest (D-006, D-013): settle gravity with the current gates, re-evaluate gates
## (blocks may have pressed or released switches), and repeat while anything moved.
## MUTATES `state`; callers pass a clone they own. Each moved object is reported once, start → rest.
static func stabilize(level: LevelDefinition, state: PuzzleState, core_cell: Vector2i,
		core_step: int = -1) -> Array[ObjectMove]:
	var moves: Array[ObjectMove] = []
	var by_object: Dictionary[String, ObjectMove] = {}
	for pass_index: int in MAX_STABILIZE_PASSES:
		var closed := SwitchGateResolver.closed_gate_cells(level, state)
		var pass_moves := GravityResolver.settle(level, state, core_cell, core_step, closed)
		if pass_moves.is_empty():
			return moves
		for move: ObjectMove in pass_moves:
			if by_object.has(move.object_id):
				by_object[move.object_id].to_cell = move.to_cell
			else:
				by_object[move.object_id] = move
				moves.append(move)
	push_error("PuzzleSimulator.stabilize did not converge in %d passes" % MAX_STABILIZE_PASSES)
	return moves


# --- Core travel --------------------------------------------------------------

static func _run_core(level: LevelDefinition, state: PuzzleState) -> ActionResult:
	if not _is_interactive_phase(state):
		return ActionResult.rejected(ActionResult.Failure.WRONG_PHASE,
			"The core cannot run in phase %s." % PuzzleState.Phase.keys()[state.phase])

	if core_position(level, state) == level.destination:
		return ActionResult.rejected(ActionResult.Failure.WRONG_PHASE, "The core is already at the end of its route.")
	var first := _next_step(level, state)
	if first.blocked:
		return ActionResult.rejected(ActionResult.Failure.ROUTE_BLOCKED,
			"The next route cell %s is blocked." % first.blocked_cell)

	var next := state.clone()
	next.core_run_count += 1
	var travel := CoreTravelResult.new()
	var moves: Array[ObjectMove] = []
	# Terminates: every step enters a cell never visited before (cells are unique across all
	# segments and the segment chain is acyclic), and the chain ends at the destination.
	while true:
		var step := _next_step(level, next)
		if step.blocked:
			next.phase = PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION
			travel.stop_reason = CoreTravelResult.StopReason.BLOCKED
			travel.blocked_cell = step.blocked_cell
			break
		if step.via_portal:
			travel.path.append(step.entry_cell)
			travel.portal_steps.append(travel.path.size())
		next.core_route_id = step.route_id
		next.core_node_index = step.index
		var cell := core_position(level, next)
		travel.path.append(cell)
		# Persistent gravity: the cell the core just vacated may let blocks slide (D-006).
		moves.append_array(stabilize(level, next, cell, travel.path.size() - 1))
		var gate_rejection := _reject_if_gate_occupied(level, next, cell)
		if gate_rejection != null:
			return gate_rejection
		if cell == level.destination:
			next.phase = PuzzleState.Phase.LEVEL_COMPLETED
			travel.stop_reason = CoreTravelResult.StopReason.DESTINATION
			break
		var checkpoint := (level.routes[step.route_id] as RouteDefinition).checkpoint_at(cell)
		if checkpoint != null:
			next.reached_checkpoint_ids.append(checkpoint.id)
			if checkpoint.auto_pause:
				next.phase = PuzzleState.Phase.CHECKPOINT_PAUSED
				travel.stop_reason = CoreTravelResult.StopReason.CHECKPOINT
				travel.checkpoint_id = checkpoint.id
				break
	return ActionResult.success(next, travel, moves)


## Where the core goes next from its current position, or why it cannot.
class _Step:
	extends RefCounted
	var blocked: bool = false
	var blocked_cell: Vector2i = Vector2i.ZERO
	var route_id: String = ""
	var index: int = 0
	var via_portal: bool = false
	var entry_cell: Vector2i = Vector2i.ZERO


## One route transition. Stepping into a segment's last node when that node is a portal entry
## carries the core straight to the exit (D-015): it never rests on the entry. The entry counts as
## blocked when it is occupied, the portal is inactive, or the exit cell is blocked.
static func _next_step(level: LevelDefinition, state: PuzzleState) -> _Step:
	var step := _Step.new()
	var route: RouteDefinition = level.routes[state.core_route_id]
	var target_index := state.core_node_index + 1
	var target := route.nodes[target_index]
	if target_index == route.last_index() and route.next_route_id != "":
		var portal := level.portal_by_id(route.exit_portal_id)
		var exit_route: RouteDefinition = level.routes[route.next_route_id]
		if is_cell_blocked(level, state, target) or not SwitchGateResolver.is_portal_active(level, state, portal) \
				or is_cell_blocked(level, state, exit_route.nodes[0]):
			step.blocked = true
			step.blocked_cell = target
			return step
		step.via_portal = true
		step.entry_cell = target
		step.route_id = exit_route.id
		step.index = 0
		return step
	if is_cell_blocked(level, state, target):
		step.blocked = true
		step.blocked_cell = target
		return step
	step.route_id = route.id
	step.index = target_index
	return step


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
	if not level.in_bounds(target) or level.is_wall(target) or target == core_cell \
			or state.object_at(target) != null or SwitchGateResolver.is_closed_gate_at(level, state, target):
		return ActionResult.rejected(ActionResult.Failure.MOVE_BLOCKED,
			"Cannot push '%s' %s: %s is not free." % [obj.id, Grid.direction_name(action.direction), target])

	var next := state.clone()
	next.object_by_id(obj.id).position = target
	var moves: Array[ObjectMove] = [ObjectMove.new(obj.id, obj.position, target, ObjectMove.Cause.PUSH)]
	moves.append_array(stabilize(level, next, core_cell))
	var gate_rejection := _reject_if_gate_occupied(level, next, core_cell)
	if gate_rejection != null:
		return gate_rejection
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
	var core_cell := core_position(level, state)
	var moves := stabilize(level, next, core_cell)
	var gate_rejection := _reject_if_gate_occupied(level, next, core_cell)
	if gate_rejection != null:
		return gate_rejection
	next.mechanism_action_count += 1
	return ActionResult.success(next, null, moves)


static func _toggle_switch(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	var rejection := _check_mechanism_available(level, state, MechanismIds.SWITCHES_SEALS)
	if rejection != null:
		return rejection
	var switch_def := level.switch_by_id(action.target_id)
	if switch_def == null or switch_def.kind != SwitchDefinition.Kind.TOGGLE:
		return ActionResult.rejected(ActionResult.Failure.INVALID_TARGET, "No toggle switch '%s'." % action.target_id)

	var next := state.clone()
	next.toggle_states[switch_def.id] = not state.toggle_states[switch_def.id]
	var core_cell := core_position(level, state)
	var moves := stabilize(level, next, core_cell)
	var gate_rejection := _reject_if_gate_occupied(level, next, core_cell)
	if gate_rejection != null:
		return gate_rejection
	next.mechanism_action_count += 1
	return ActionResult.success(next, null, moves)


# --- Helpers ------------------------------------------------------------------

## D-013: a resolved result may never leave a closed gate on a block or the core.
static func _reject_if_gate_occupied(level: LevelDefinition, state: PuzzleState, core_cell: Vector2i) -> ActionResult:
	var gate_ids := SwitchGateResolver.occupied_closed_gates(level, state, core_cell)
	if gate_ids.is_empty():
		return null
	return ActionResult.rejected(ActionResult.Failure.GATE_OCCUPIED,
		"That would close gate %s on an occupied cell." % ", ".join(gate_ids))


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
