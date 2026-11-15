class_name Grid
extends RefCounted
## Integer grid helpers. Coordinates: x increases right, y increases down.

enum Direction { UP, RIGHT, DOWN, LEFT }

const _OFFSETS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const _NAMES := ["up", "right", "down", "left"]


static func in_bounds(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


static func are_orthogonal_neighbours(a: Vector2i, b: Vector2i) -> bool:
	var delta := (a - b).abs()
	return delta.x + delta.y == 1


static func offset(direction: Direction) -> Vector2i:
	return _OFFSETS[direction]


## How far `cell` lies along `direction` (larger = further). Used for deterministic ordering.
static func progress_along(cell: Vector2i, direction: Direction) -> int:
	var step := offset(direction)
	return cell.x * step.x + cell.y * step.y


static func direction_name(direction: Direction) -> String:
	return _NAMES[direction]


## Returns the Direction for a lowercase name, or -1 if the name is unknown.
static func parse_direction(direction_name_value: String) -> int:
	return _NAMES.find(direction_name_value)
