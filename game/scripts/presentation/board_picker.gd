class_name BoardPicker
extends RefCounted
## Screen → board hit-testing with plain ray math (no physics engine involved).
## Presentation only: it reports what is under the pointer; rules stay in the simulation.


class Hit:
	extends RefCounted
	## Id of the nearest block under the pointer, or "" if none.
	var object_id: String = ""
	## Board cell under the pointer on the floor plane, valid only when has_cell.
	var cell: Vector2i = Vector2i(-1, -1)
	var has_cell: bool = false


static func pick(camera: Camera3D, screen_position: Vector2, level: LevelDefinition, state: PuzzleState) -> Hit:
	var hit := Hit.new()
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var nearest := INF
	var half := Vector3.ONE * BoardRenderer3D.BLOCK_SIZE * 0.5
	for obj: MovableObject in state.objects:
		var center := BoardRenderer3D.object_world_position(obj.position)
		var point: Variant = AABB(center - half, half * 2.0).intersects_ray(origin, direction)
		if point != null:
			var distance := origin.distance_to(point as Vector3)
			if distance < nearest:
				nearest = distance
				hit.object_id = obj.id
	if absf(direction.y) > 0.000001:
		var t := -origin.y / direction.y
		if t > 0.0:
			var cell := BoardCoords.world_to_cell(origin + direction * t)
			if level.in_bounds(cell):
				hit.cell = cell
				hit.has_cell = true
	return hit
