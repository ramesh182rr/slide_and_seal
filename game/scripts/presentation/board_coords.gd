class_name BoardCoords
extends RefCounted
## The ONLY grid ↔ world mapping (docs/04 §8). Grid x → world +X, grid y → world +Z, up is +Y.

const CELL_SIZE := 1.0


static func cell_to_world(cell: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, height, cell.y * CELL_SIZE)


## Inverse of cell_to_world (height ignored). May return a cell outside the board.
static func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(roundi(world.x / CELL_SIZE), roundi(world.z / CELL_SIZE))


## World-space centre of the board's cell area, at floor height.
static func board_center(board_size: Vector2i) -> Vector3:
	return Vector3((board_size.x - 1) * 0.5 * CELL_SIZE, 0.0, (board_size.y - 1) * 0.5 * CELL_SIZE)


## World-space centre of a rectangle of cells.
static func rect_center(rect: Rect2i, height: float = 0.0) -> Vector3:
	var center := Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * 0.5
	return Vector3(center.x * CELL_SIZE, height, center.y * CELL_SIZE)


## Rotation about +Y that turns a marker pointing at grid UP (world -Z) to face `direction`.
static func direction_yaw(direction: Grid.Direction) -> float:
	match direction:
		Grid.Direction.RIGHT:
			return -PI / 2.0
		Grid.Direction.DOWN:
			return PI
		Grid.Direction.LEFT:
			return PI / 2.0
	return 0.0
