class_name AnimationDirector
extends Node
## Plays back an already-committed ActionResult by interpolating between the old and new state.
## Animation never changes puzzle state (docs/05 §6); the controller snaps the board to the
## committed state afterwards, so playback can never drift from the simulation.

const CORE_STEP_SECONDS := 0.16
const PUSH_SECONDS := 0.18
const SLIDE_SECONDS_PER_CELL := 0.08
const ZONE_TURN_SECONDS := 0.22
const GATE_SECONDS := 0.25

## When true, nothing animates (reduced motion; also used by tests).
var instant: bool = false
var _board: BoardRenderer3D


func setup(board: BoardRenderer3D) -> void:
	_board = board


## Resolves when playback is finished. Returns immediately when instant or nothing moves.
func play(before: PuzzleState, result: ActionResult) -> void:
	if instant:
		return
	var tween := create_tween()
	var steps := _queue_zone_turns(tween, before, result.state)
	if result.travel != null:
		steps += _queue_travel(tween, result)
	else:
		steps += _queue_moves(tween, result.object_moves)
	steps += _queue_gate_changes(tween, before, result.state)
	if steps == 0:
		tween.kill()
		return
	await tween.finished


func _queue_zone_turns(tween: Tween, before: PuzzleState, after: PuzzleState) -> int:
	var count := 0
	for zone_id: String in after.gravity_directions.keys():
		var from_yaw := BoardCoords.direction_yaw(before.gravity_directions[zone_id])
		var to_yaw := BoardCoords.direction_yaw(after.gravity_directions[zone_id])
		if is_equal_approx(from_yaw, to_yaw):
			continue
		for pivot: Node3D in _board.zone_chevrons(zone_id):
			var turn := func(t: float) -> void: pivot.rotation.y = lerp_angle(from_yaw, to_yaw, t)
			_tweener(tween, count > 0).tween_method(turn, 0.0, 1.0, ZONE_TURN_SECONDS)
			count += 1
	return count


## Gates that opened or closed rise or sink together after the moves that caused them.
func _queue_gate_changes(tween: Tween, before: PuzzleState, after: PuzzleState) -> int:
	var level := _board.level()
	var count := 0
	for gate: GateDefinition in level.gates:
		var open_after := SwitchGateResolver.is_gate_open(level, after, gate)
		if open_after == SwitchGateResolver.is_gate_open(level, before, gate):
			continue
		var node := _board.fixtures().gate_node(gate.id)
		_tweener(tween, count > 0).tween_property(node, "position:y", MechanismFixtures3D.gate_y(open_after),
			GATE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		count += 1
	return count


## Core moves one cell at a time; gravity moves triggered by a step follow that step.
func _queue_travel(tween: Tween, result: ActionResult) -> int:
	var count := 0
	var core := _board.core_node()
	for i: int in result.travel.path.size():
		var target := BoardRenderer3D.core_world_position(result.travel.path[i])
		if result.travel.portal_steps.has(i):
			# Teleport: jump to the exit instead of sliding across the board (placeholder effect).
			tween.tween_callback(func() -> void: core.position = target)
		else:
			tween.tween_property(core, "position", target, CORE_STEP_SECONDS)
		count += 1
		var first := true
		for move: ObjectMove in result.object_moves:
			if move.core_step == i:
				_queue_move(tween, move, not first)
				first = false
				count += 1
	return count


## A push plays first; gravity slides then play together.
func _queue_moves(tween: Tween, moves: Array[ObjectMove]) -> int:
	var gravity_started := false
	for move: ObjectMove in moves:
		var parallel := move.cause == ObjectMove.Cause.GRAVITY and gravity_started
		_queue_move(tween, move, parallel)
		gravity_started = gravity_started or move.cause == ObjectMove.Cause.GRAVITY
	return moves.size()


func _queue_move(tween: Tween, move: ObjectMove, parallel: bool) -> void:
	var node := _board.object_node(move.object_id)
	var target := BoardRenderer3D.object_world_position(move.to_cell)
	if move.cause == ObjectMove.Cause.PUSH:
		_tweener(tween, parallel).tween_property(node, "position", target, PUSH_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		var cells := absi(move.to_cell.x - move.from_cell.x) + absi(move.to_cell.y - move.from_cell.y)
		_tweener(tween, parallel).tween_property(node, "position", target, SLIDE_SECONDS_PER_CELL * cells) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


static func _tweener(tween: Tween, parallel: bool) -> Tween:
	return tween.parallel() if parallel else tween
