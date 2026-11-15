class_name GravityResolver
extends RefCounted
## Deterministic gravity settling for local zones (decision D-006).


## Settles every gravity-affected object inside each zone. MUTATES `state`; callers must pass
## a fresh clone they own. `core_cell` and `closed_cells` (closed gates) are obstacles.
## Returns the moves made, in resolution order. One pass; PuzzleSimulator.stabilize iterates
## this with gate re-evaluation.
static func settle(level: LevelDefinition, state: PuzzleState, core_cell: Vector2i,
		core_step: int = -1, closed_cells: Dictionary[Vector2i, bool] = {}) -> Array[ObjectMove]:
	var moves: Array[ObjectMove] = []
	for zone: GravityZoneDefinition in level.gravity_zones:
		var direction: Grid.Direction = state.gravity_directions[zone.id]
		var step := Grid.offset(direction)
		for obj: MovableObject in _members_in_order(zone, state, direction):
			var start := obj.position
			while true:
				var next_cell := obj.position + step
				if not zone.contains(next_cell) or level.is_wall(next_cell) or next_cell == core_cell \
						or closed_cells.has(next_cell) or state.object_at(next_cell) != null:
					break
				obj.position = next_cell
			if obj.position != start:
				moves.append(ObjectMove.new(obj.id, start, obj.position, ObjectMove.Cause.GRAVITY, core_step))
	return moves


## Gravity-affected objects in the zone, farthest along `direction` first, then by id.
## With this order a single pass settles every object exactly.
static func _members_in_order(zone: GravityZoneDefinition, state: PuzzleState,
		direction: Grid.Direction) -> Array[MovableObject]:
	var members: Array[MovableObject] = []
	for obj: MovableObject in state.objects:
		if obj.gravity_affected and zone.contains(obj.position):
			members.append(obj)
	members.sort_custom(func(a: MovableObject, b: MovableObject) -> bool:
		var progress_a := Grid.progress_along(a.position, direction)
		var progress_b := Grid.progress_along(b.position, direction)
		if progress_a != progress_b:
			return progress_a > progress_b
		return a.id < b.id)
	return members
