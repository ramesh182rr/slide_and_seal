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


## Adds a block. Returns `data` for chaining.
static func add_block(data: Dictionary, id: String, cell: Vector2i, pushable: bool = true,
		gravity_affected: bool = true) -> Dictionary:
	(data["objects"] as Array).append({
		"id": id, "kind": "block", "position": [cell.x, cell.y],
		"pushable": pushable, "gravity_affected": gravity_affected,
	})
	return data


## Adds a gravity zone. Directions are names ("up", "down", ...). Returns `data` for chaining.
static func add_gravity_zone(data: Dictionary, id: String, position: Vector2i, size: Vector2i,
		direction: String, allowed: Array) -> Dictionary:
	if not data.has("mechanisms"):
		data["mechanisms"] = {}
	if not data["mechanisms"].has("gravity_zones"):
		data["mechanisms"]["gravity_zones"] = []
	(data["mechanisms"]["gravity_zones"] as Array).append({
		"id": id, "position": [position.x, position.y], "size": [size.x, size.y],
		"direction": direction, "allowed_directions": allowed,
	})
	return data


## Adds a switch ("pressure" or "toggle"). Returns `data` for chaining.
static func add_switch(data: Dictionary, id: String, kind: String, cell: Vector2i, initially_on: bool = false) -> Dictionary:
	_collection(data, "switches").append(
		{"id": id, "kind": kind, "position": [cell.x, cell.y]}.merged({"initially_on": initially_on} if kind == "toggle" else {}))
	return data


## Adds a gate that opens when all `requires` switches are on. Returns `data` for chaining.
static func add_gate(data: Dictionary, id: String, cell: Vector2i, requires: Array) -> Dictionary:
	_collection(data, "gates").append({"id": id, "position": [cell.x, cell.y], "requires": requires})
	return data


static func _collection(data: Dictionary, key: String) -> Array:
	if not data.has("mechanisms"):
		data["mechanisms"] = {}
	if not data["mechanisms"].has(key):
		data["mechanisms"][key] = []
	return data["mechanisms"][key]


## Sets the mechanisms allowed during setup and at every checkpoint. Returns `data` for chaining.
static func allow_everywhere(data: Dictionary, mechanisms: Array) -> Dictionary:
	data["setup"] = {"allowed_mechanisms": mechanisms.duplicate()}
	for route_id: String in (data["routes"] as Dictionary).keys():
		for checkpoint: Dictionary in data["routes"][route_id]["checkpoints"]:
			checkpoint["allowed_mechanisms"] = mechanisms.duplicate()
	return data


## Loads a fixture, returning null on validation failure (the test should assert on that).
static func build(data: Dictionary) -> LevelDefinition:
	return LevelLoader.from_dict(data).level
