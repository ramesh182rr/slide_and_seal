class_name MagnetResolver
extends RefCounted
## One magnetic pulse (decisions D-027 – D-029). MUTATES `state`; callers pass a clone they own.
## Along each of the four lines from the magnet, only the first block reacts: a neutral block
## shields; a polarised block moves one cell toward (opposite) or away from (like) the magnet,
## if that cell is free. The lines never share cells, so the moves cannot conflict.


static func pulse(level: LevelDefinition, state: PuzzleState, magnet: MagnetDefinition,
		core_cell: Vector2i) -> Array[ObjectMove]:
	var moves: Array[ObjectMove] = []
	var positive: bool = state.magnet_positive[magnet.id]
	for direction: int in 4:
		var step := Grid.offset(direction as Grid.Direction)
		var cell := magnet.position
		while true:
			cell += step
			if not level.in_bounds(cell) or PuzzleSimulator.is_wall_at(level, state, cell) \
					or SwitchGateResolver.is_closed_gate_at(level, state, cell):
				break
			var obj := state.object_at(cell)
			if obj == null:
				continue  # The field passes empty cells and the core's cell (D-029).
			if obj.polarity != 0:
				var attract := (obj.polarity > 0) != positive
				var target := cell - step if attract else cell + step
				if _is_free(level, state, target, core_cell):
					moves.append(ObjectMove.new(obj.id, obj.position, target, ObjectMove.Cause.MAGNET))
					obj.position = target
			break  # The first block met is the only one affected; it shields the rest.
	return moves


static func _is_free(level: LevelDefinition, state: PuzzleState, cell: Vector2i, core_cell: Vector2i) -> bool:
	return level.in_bounds(cell) and not PuzzleSimulator.is_wall_at(level, state, cell) \
		and state.object_at(cell) == null and cell != core_cell \
		and not SwitchGateResolver.is_closed_gate_at(level, state, cell)
