class_name LevelDefinition
extends RefCounted
## Authored level data produced by LevelLoader. Treated as immutable at runtime.

var schema_version: int = 0
var id: String = ""
var title: String = ""
var world_id: String = ""
var access: String = ""
var board_size: Vector2i = Vector2i.ZERO
## Set of wall cells (values are always true).
var walls: Dictionary[Vector2i, bool] = {}
var routes: Dictionary[String, RouteDefinition] = {}
var start_route_id: String = ""
var core_start: Vector2i = Vector2i.ZERO
var destination: Vector2i = Vector2i.ZERO
var seal_id: String = ""
## Sorted by id.
var initial_objects: Array[MovableObject] = []
var target_actions: int = 0
## -1 when no solver-proven optimum exists.
var optimal_actions: int = -1


func in_bounds(cell: Vector2i) -> bool:
	return Grid.in_bounds(cell, board_size)


func is_wall(cell: Vector2i) -> bool:
	return walls.has(cell)


## Returns a fresh copy of the exact authored starting state.
func create_initial_state() -> PuzzleState:
	var state := PuzzleState.new()
	state.phase = PuzzleState.Phase.SETUP
	state.core_route_id = start_route_id
	state.core_node_index = 0
	for obj: MovableObject in initial_objects:
		state.objects.append(obj.clone())
	state.sort_objects()
	return state
