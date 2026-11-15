class_name LevelFixtures
extends RefCounted
## Small level dictionaries for tests. Each call returns a fresh copy that tests may modify.


## 7x3 board. Route along y = 1 from (0,1) to (6,1); auto-pause checkpoint "cp" at (3,1).
static func corridor() -> Dictionary:
	return {
		"schema_version": 3,
		"id": "test_corridor",
		"title": "Test Corridor",
		"world_id": "test_world",
		"access": "free",
		"board": {"width": 7, "height": 3},
		"core": {"position": [0, 1], "route_id": "main"},
		"destination": {"position": [6, 1], "seal_id": "seal"},
		"terrain": {"walls": []},
		"routes": {
			"main": {
				"nodes": [[0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1]],
				"checkpoints": [
					{"id": "cp", "position": [3, 1], "auto_pause": true, "allowed_mechanisms": []},
				],
			},
		},
		"objects": [],
		"objectives": [{"type": "reach_destination", "target_id": "seal"}],
		"scoring": {"target_actions": 0, "optimal_actions": null},
	}


## The corridor with blocks at the given cells (ids block_0, block_1, ...).
static func corridor_with_blocks(cells: Array[Vector2i]) -> Dictionary:
	var data := corridor()
	var objects: Array = data["objects"]
	for i: int in cells.size():
		objects.append({"id": "block_%d" % i, "kind": "block", "position": [cells[i].x, cells[i].y]})
	return data


## Loads a fixture, returning null on validation failure (the test should assert on that).
static func build(data: Dictionary) -> LevelDefinition:
	return LevelLoader.from_dict(data).level
