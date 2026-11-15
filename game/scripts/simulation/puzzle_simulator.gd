class_name PuzzleSimulator
extends RefCounted
## The single source of puzzle rules.
## Pure and deterministic: never mutates its inputs, uses no scene tree, physics, time or randomness.
## Gameplay, preview, hints, solver and validator must all go through these functions.

## Safety bound for stabilize(); gravity only moves blocks forward, so real levels converge quickly.
const MAX_STABILIZE_PASSES := 64
## Defensive bound on one core run (32x32 board = 1024 cells).
const MAX_TRAVEL_STEPS := 2048


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
		PuzzleAction.Kind.ROTATE_SECTION:
			return _rotate_section(level, state, action)
		PuzzleAction.Kind.FLIP_REFLECTOR:
			return _flip_reflector(level, state, action)
	return ActionResult.rejected(ActionResult.Failure.UNKNOWN_ACTION, "Unknown action kind %d." % action.kind)


## Preview is the real rule set without committing: identical to apply_action by construction.
## The returned state is a new object; the caller's state is never touched.
static func preview_action(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	return apply_action(level, state, action)


static func core_position(level: LevelDefinition, state: PuzzleState) -> Vector2i:
	return route_cell(level, state, level.routes[state.core_route_id], state.core_node_index)


## Current cell of a route node: track pieces turn with their section (D-017).
static func route_cell(level: LevelDefinition, state: PuzzleState, route: RouteDefinition, index: int) -> Vector2i:
	var node := route.nodes[index]
	if route.section_id == "":
		return node
	return level.rotating_section(route.section_id).rotate_cell(node, state.section_turns[route.section_id])


## Solid for blocks and the core: terrain walls plus emitters and reflectors (D-023).
static func is_wall_at(level: LevelDefinition, state: PuzzleState, cell: Vector2i) -> bool:
	return level.is_solid_fixture(cell) or is_terrain_wall_at(level, state, cell)


## Terrain walls only. Walls inside rotating sections turn with them (D-018); others are static.
static func is_terrain_wall_at(level: LevelDefinition, state: PuzzleState, cell: Vector2i) -> bool:
	var section := level.section_at(cell)
	if section == null:
		return level.is_wall(cell)
	return level.is_wall(section.authored_cell(cell, state.section_turns[section.id]))


## A cell the core cannot enter.
static func is_cell_blocked(level: LevelDefinition, state: PuzzleState, cell: Vector2i) -> bool:
	return not level.in_bounds(cell) or is_wall_at(level, state, cell) or state.object_at(cell) != null \
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
		EnergyResolver.update_power(level, state)
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
	# Terminates: within one run each step enters a new node, the loader rejects any layout in which
	# a fixed segment could be reached from itself (D-017), and MAX_TRAVEL_STEPS is a final guard.
	var steps_taken := 0
	while true:
		steps_taken += 1
		if steps_taken > MAX_TRAVEL_STEPS:
			push_error("Core travel exceeded %d steps; the level's route graph is invalid" % MAX_TRAVEL_STEPS)
			break
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
		next.core_route_reversed = step.reversed
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
	var reversed: bool = false
	var via_portal: bool = false
	var entry_cell: Vector2i = Vector2i.ZERO


## One route transition.
## - Inside a segment: the next node in the travel direction.
## - Into a portal entry (last node of a fixed segment with a portal link): straight to the exit (D-015);
##   blocked when the entry is occupied, the portal is inactive, or the exit is blocked.
## - At the open end of a segment: a junction through a rotating section, by adjacency (D-017).
static func _next_step(level: LevelDefinition, state: PuzzleState) -> _Step:
	var route: RouteDefinition = level.routes[state.core_route_id]
	var reversed := state.core_route_reversed
	var end_index := 0 if reversed else route.last_index()
	if state.core_node_index == end_index:
		return _junction_step(level, state, route)
	var target_index := state.core_node_index + (-1 if reversed else 1)
	var target := route_cell(level, state, route, target_index)
	var step := _Step.new()
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
	step.reversed = reversed
	return step


## From the open end of a segment, continue into the segment that currently lines up (D-017):
## a fixed segment's end leads into a track piece whose (rotated) end is adjacent; a track piece's
## end leads into the fixed segment whose start is adjacent. Ids are scanned in sorted order; the
## loader guarantees at most one candidate.
static func _junction_step(level: LevelDefinition, state: PuzzleState, current: RouteDefinition) -> _Step:
	var step := _Step.new()
	var here := core_position(level, state)
	var route_ids: Array = level.routes.keys()
	route_ids.sort()
	for route_id: String in route_ids:
		var candidate: RouteDefinition = level.routes[route_id]
		if candidate == current or (candidate.section_id == "") == (current.section_id == ""):
			continue
		var first := route_cell(level, state, candidate, 0)
		var last := route_cell(level, state, candidate, candidate.last_index())
		if Grid.are_orthogonal_neighbours(here, first):
			step.route_id = candidate.id
			step.index = 0
		elif candidate.section_id != "" and Grid.are_orthogonal_neighbours(here, last):
			step.route_id = candidate.id
			step.index = candidate.last_index()
			step.reversed = true
		else:
			continue
		var entry := route_cell(level, state, candidate, step.index)
		if is_cell_blocked(level, state, entry) \
				or candidate.section_id != "" and not _can_pass_through(level, state, candidate, step.reversed, route_ids):
			step.blocked = true
			step.blocked_cell = entry
		return step
	# Nothing lines up: wait for the player to turn a section.
	step.blocked = true
	step.blocked_cell = here + _heading(level, state, current)
	return step


## D-021: a track piece may be entered only if the core can pass straight through it: the far end
## lines up with a fixed segment's start, and every piece cell plus that start cell is free.
static func _can_pass_through(level: LevelDefinition, state: PuzzleState, piece: RouteDefinition,
		reversed: bool, route_ids: Array) -> bool:
	for index: int in piece.nodes.size():
		if is_cell_blocked(level, state, route_cell(level, state, piece, index)):
			return false
	var far := route_cell(level, state, piece, 0 if reversed else piece.last_index())
	for route_id: String in route_ids:
		var exit_route: RouteDefinition = level.routes[route_id]
		if exit_route.section_id == "" and Grid.are_orthogonal_neighbours(far, exit_route.nodes[0]):
			return not is_cell_blocked(level, state, exit_route.nodes[0])
	return false


## Direction of travel at the end of the current segment (for reporting the blocked cell).
static func _heading(level: LevelDefinition, state: PuzzleState, route: RouteDefinition) -> Vector2i:
	var reversed := state.core_route_reversed
	var end_index := 0 if reversed else route.last_index()
	var before_index := end_index + (1 if reversed else -1)
	return route_cell(level, state, route, end_index) - route_cell(level, state, route, before_index)


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
	if not level.in_bounds(target) or is_wall_at(level, state, target) or target == core_cell \
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


static func _rotate_section(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	var rejection := _check_mechanism_available(level, state, MechanismIds.ROTATING_SECTIONS)
	if rejection != null:
		return rejection
	var section := level.rotating_section(action.target_id)
	if section == null:
		return ActionResult.rejected(ActionResult.Failure.INVALID_TARGET, "No rotating section '%s'." % action.target_id)
	if action.clockwise and not section.allow_clockwise or not action.clockwise and not section.allow_counterclockwise:
		return ActionResult.rejected(ActionResult.Failure.INVALID_DIRECTION,
			"Section '%s' cannot turn %s." % [section.id, "clockwise" if action.clockwise else "counterclockwise"])
	var core_cell := core_position(level, state)
	if section.contains(core_cell):
		return ActionResult.rejected(ActionResult.Failure.MOVE_BLOCKED,
			"Section '%s' cannot turn while the core is on it." % section.id)

	var next := state.clone()
	var quarter := 1 if action.clockwise else 3
	next.section_turns[section.id] = posmod(state.section_turns[section.id] + quarter, 4)
	# Blocks inside move with the floor: a quarter turn of the square is a one-to-one remap (D-018).
	var moves: Array[ObjectMove] = []
	for obj: MovableObject in next.objects:
		if section.contains(obj.position):
			var from := obj.position
			obj.position = section.rotate_cell(from, quarter)
			moves.append(ObjectMove.new(obj.id, from, obj.position, ObjectMove.Cause.ROTATION))
	moves.append_array(stabilize(level, next, core_cell))
	var gate_rejection := _reject_if_gate_occupied(level, next, core_cell)
	if gate_rejection != null:
		return gate_rejection
	next.mechanism_action_count += 1
	return ActionResult.success(next, null, moves)


static func _flip_reflector(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	var rejection := _check_mechanism_available(level, state, MechanismIds.ENERGY_ROUTING)
	if rejection != null:
		return rejection
	var reflector := level.reflector_by_id(action.target_id)
	if reflector == null:
		return ActionResult.rejected(ActionResult.Failure.INVALID_TARGET, "No reflector '%s'." % action.target_id)
	var next := state.clone()
	next.reflector_slash[reflector.id] = not state.reflector_slash[reflector.id]
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
