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
const SECTION_TURN_SECONDS := 0.4
const MIRROR_FLIP_SECONDS := 0.25

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
	steps += _queue_section_turns(tween, before, result)
	steps += _queue_mirror_flips(tween, before, result.state)
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
		if count == 0:
			tween.tween_callback(func() -> void: AudioDirector.play("turn"))
		for pivot: Node3D in _board.zone_chevrons(zone_id):
			var turn := func(t: float) -> void: pivot.rotation.y = lerp_angle(from_yaw, to_yaw, t)
			_tweener(tween, count > 0).tween_method(turn, 0.0, 1.0, ZONE_TURN_SECONDS)
			count += 1
	return count


## Flipped mirrors swing to their new diagonal. Beams are redrawn when the board snaps afterwards.
func _queue_mirror_flips(tween: Tween, before: PuzzleState, after: PuzzleState) -> int:
	var count := 0
	for reflector_id: String in after.reflector_slash.keys():
		if before.reflector_slash[reflector_id] == after.reflector_slash[reflector_id]:
			continue
		var pivot := _board.fixtures().reflector_pivot(reflector_id)
		var target := MechanismFixtures3D.reflector_yaw(after.reflector_slash[reflector_id])
		_tweener(tween, count > 0).tween_property(pivot, "rotation:y", target, MIRROR_FLIP_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		count += 1
	return count


## Turned sections rotate their platform; blocks on it orbit the centre in step (D-018).
func _queue_section_turns(tween: Tween, before: PuzzleState, result: ActionResult) -> int:
	var level := _board.level()
	var count := 0
	for section: RotatingSectionDefinition in level.rotating_sections:
		var turns_before: int = before.section_turns[section.id]
		var turns_after: int = result.state.section_turns[section.id]
		if turns_before == turns_after:
			continue
		tween.tween_callback(func() -> void: AudioDirector.play("turn", 0.85))
		var pivot := _board.section_pivot(section.id)
		var from_yaw := BoardRenderer3D.section_yaw(turns_before)
		# The shortest signed quarter turn (one action = one quarter turn).
		var delta := -PI / 2.0 if posmod(turns_after - turns_before, 4) == 1 else PI / 2.0
		var spin := func(t: float) -> void: pivot.rotation.y = from_yaw + delta * t
		_tweener(tween, count > 0).tween_method(spin, 0.0, 1.0, SECTION_TURN_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		count += 1
		var center := pivot.position
		for move: ObjectMove in result.object_moves:
			if move.cause != ObjectMove.Cause.ROTATION or not section.contains(move.from_cell):
				continue
			var node := _board.object_node(move.object_id)
			var start := BoardRenderer3D.object_world_position(move.from_cell)
			var orbit := func(t: float) -> void: node.position = center + (start - center).rotated(Vector3.UP, delta * t)
			tween.parallel().tween_method(orbit, 0.0, 1.0, SECTION_TURN_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return count


## Gates that opened or closed rise or sink together after the moves that caused them.
func _queue_gate_changes(tween: Tween, before: PuzzleState, after: PuzzleState) -> int:
	var level := _board.level()
	var count := 0
	for gate: GateDefinition in level.gates:
		var open_after := SwitchGateResolver.is_gate_open(level, after, gate)
		if open_after == SwitchGateResolver.is_gate_open(level, before, gate):
			continue
		if count == 0:
			tween.tween_callback(func() -> void: AudioDirector.play("gate"))
		var node := _board.fixtures().gate_node(gate.id)
		_tweener(tween, count > 0).tween_property(node, "position:y", MechanismFixtures3D.gate_y(open_after),
			GATE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
			# Each step ticks a little higher than the last, so a long run sings upward.
			var pitch := 1.0 + minf(i, 12) * 0.035
			tween.tween_callback(func() -> void: AudioDirector.play("step", pitch, -4.0))
			tween.tween_property(core, "position", target, CORE_STEP_SECONDS)
		count += 1
		var first := true
		for move: ObjectMove in result.object_moves:
			if move.core_step == i:
				_queue_move(tween, move, not first)
				first = false
				count += 1
	return count


## A push plays first; gravity slides then play together. Rotation moves are played by
## _queue_section_turns (blocks ride the turning platform), so they are skipped here.
func _queue_moves(tween: Tween, moves: Array[ObjectMove]) -> int:
	var gravity_started := false
	var count := 0
	var magnet_started := false
	for move: ObjectMove in moves:
		if move.cause == ObjectMove.Cause.ROTATION:
			continue
		count += 1
		# One pulse moves its blocks together; gravity slides then play together.
		var parallel := move.cause == ObjectMove.Cause.GRAVITY and gravity_started \
			or move.cause == ObjectMove.Cause.MAGNET and magnet_started
		magnet_started = magnet_started or move.cause == ObjectMove.Cause.MAGNET
		_queue_move(tween, move, parallel)
		gravity_started = gravity_started or move.cause == ObjectMove.Cause.GRAVITY
	return count


func _queue_move(tween: Tween, move: ObjectMove, parallel: bool) -> void:
	var node := _board.object_node(move.object_id)
	var target := BoardRenderer3D.object_world_position(move.to_cell)
	if move.cause == ObjectMove.Cause.PUSH:
		if not parallel:
			tween.tween_callback(func() -> void: AudioDirector.play("slide"))
		_tweener(tween, parallel).tween_property(node, "position", target, PUSH_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		var cells := absi(move.to_cell.x - move.from_cell.x) + absi(move.to_cell.y - move.from_cell.y)
		_tweener(tween, parallel).tween_property(node, "position", target, SLIDE_SECONDS_PER_CELL * cells) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Landing: a squash that overlaps whatever plays next (decoration; never awaited).
	var object_id := move.object_id
	tween.tween_callback(func() -> void: _board.land_pulse(object_id))


static func _tweener(tween: Tween, parallel: bool) -> Tween:
	return tween.parallel() if parallel else tween
