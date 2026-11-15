class_name GravityZoneDefinition
extends RefCounted
## An authored local gravity zone (decision D-006). Immutable after loading.
## The zone's current direction is runtime state: PuzzleState.gravity_directions.

var id: String = ""
## Cells covered by the zone (end edge exclusive, as Rect2i.has_point).
var rect: Rect2i = Rect2i()
var initial_direction: Grid.Direction = Grid.Direction.DOWN
## Directions the player may set. Always contains initial_direction.
var allowed_directions: Array[Grid.Direction] = []


func contains(cell: Vector2i) -> bool:
	return rect.has_point(cell)
