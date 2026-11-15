class_name Grid
extends RefCounted
## Integer grid helpers. Coordinates: x increases right, y increases down.


static func in_bounds(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


static func are_orthogonal_neighbours(a: Vector2i, b: Vector2i) -> bool:
	var delta := (a - b).abs()
	return delta.x + delta.y == 1
