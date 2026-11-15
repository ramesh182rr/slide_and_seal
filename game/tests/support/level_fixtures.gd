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


## 7x3 board split by a wall column at x = 3. Segment "a" (0,1)→(2,1) ends on entry portal "p_in";
## segment "b" (4,1)→(6,1) starts on exit portal "p_out" and ends at the seal. Checkpoint "cp" at (5,1).
static func portal_corridor(portal_requires: Array = []) -> Dictionary:
	var data := corridor()
	data["id"] = "test_portal_corridor"
	data["terrain"] = {"walls": [[3, 0], [3, 1], [3, 2]]}
	data["routes"] = {
		"a": {"nodes": [[0, 1], [1, 1], [2, 1]], "checkpoints": []},
		"b": {
			"nodes": [[4, 1], [5, 1], [6, 1]],
			"checkpoints": [{"id": "cp", "position": [5, 1], "auto_pause": true, "allowed_mechanisms": []}],
		},
	}
	data["core"]["route_id"] = "a"
	add_portal(data, "p_in", Vector2i(2, 1), "p_out", portal_requires)
	add_portal(data, "p_out", Vector2i(4, 1))
	return data


## 7x5 board. Fixed segment "a" (0,2)→(2,2) ends beside 3x3 section "s" at (3,1); track piece "t"
## inside runs vertically (4,1)→(4,3) at turn 0, so it does not line up until the section turns.
## Fixed segment "b" (6,2)→(6,4) starts beside the section's far side and ends at the seal (6,4).
## Checkpoint "cp" at (1,2). Rotation allowed everywhere; both directions.
static func rotation_corridor() -> Dictionary:
	var data := corridor()
	data["id"] = "test_rotation_corridor"
	data["board"] = {"width": 7, "height": 5}
	data["core"] = {"position": [0, 2], "route_id": "a"}
	data["destination"] = {"position": [6, 4], "seal_id": "seal"}
	data["terrain"] = {"walls": []}
	data["routes"] = {
		"a": {
			"nodes": [[0, 2], [1, 2], [2, 2]],
			"checkpoints": [{"id": "cp", "position": [1, 2], "auto_pause": true, "allowed_mechanisms": []}],
		},
		"t": {"nodes": [[4, 1], [4, 2], [4, 3]], "checkpoints": []},
		"b": {"nodes": [[6, 2], [6, 3], [6, 4]], "checkpoints": []},
	}
	add_rotating_section(data, "s", Vector2i(3, 1), 3, ["clockwise", "counterclockwise"])
	return allow_everywhere(data, [MechanismIds.ROTATING_SECTIONS])


static func add_rotating_section(data: Dictionary, id: String, origin: Vector2i, size: int, allowed: Array) -> Dictionary:
	_collection(data, "rotating_sections").append(
		{"id": id, "position": [origin.x, origin.y], "size": size, "allowed_directions": allowed})
	return data


## Adds a portal. `exit` = id of the portal it carries the core to ("" for exit-only).
static func add_portal(data: Dictionary, id: String, cell: Vector2i, exit: String = "", requires: Array = []) -> Dictionary:
	var portal := {"id": id, "position": [cell.x, cell.y], "requires": requires}
	if exit != "":
		portal["exit"] = exit
	_collection(data, "portals").append(portal)
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
