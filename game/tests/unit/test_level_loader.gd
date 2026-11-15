extends TestCase
## LevelLoader: schema v3 parsing and validation (docs/LEVEL_SCHEMA.md).

const LEVEL_001_PATH := "res://data/levels/world_01_level_001.json"


func test_loads_world_01_level_001() -> void:
	var result := LevelLoader.load_file(LEVEL_001_PATH)
	assert_eq(result.errors, PackedStringArray(), "load errors")
	if not result.is_ok():
		return
	var level := result.level
	assert_eq(level.id, "world_01_level_001")
	assert_eq(level.title, "The First Signal")
	assert_eq(level.board_size, Vector2i(7, 7))
	assert_eq(level.core_start, Vector2i(0, 3))
	assert_eq(level.destination, Vector2i(6, 3))
	assert_eq(level.seal_id, "seal_final")
	assert_eq(level.walls.size(), 4)
	assert_true(level.is_wall(Vector2i(3, 1)))
	assert_eq(level.optimal_actions, -1, "null optimal_actions maps to -1")
	var route := level.routes["route_main"]
	assert_eq(route.nodes.size(), 7)
	assert_eq(route.checkpoints.size(), 1)
	assert_eq(route.checkpoints[0].id, "checkpoint_01")
	assert_eq(route.checkpoints[0].position, Vector2i(3, 3))
	assert_true(route.checkpoints[0].auto_pause)


func test_fixture_is_valid() -> void:
	var result := LevelLoader.from_dict(LevelFixtures.corridor())
	assert_eq(result.errors, PackedStringArray())
	assert_true(result.is_ok())


func test_accepts_integral_float_coordinates() -> void:
	var data := LevelFixtures.corridor()
	data["core"]["position"] = [0.0, 1.0]
	assert_true(LevelLoader.from_dict(data).is_ok())


func test_objects_are_sorted_by_id() -> void:
	var data := LevelFixtures.corridor()
	data["objects"] = [
		{"id": "zeta", "kind": "block", "position": [2, 0]},
		{"id": "alpha", "kind": "block", "position": [4, 0]},
	]
	var level := LevelFixtures.build(data)
	assert_not_null(level)
	if level != null:
		assert_eq(level.initial_objects[0].id, "alpha")
		assert_eq(level.initial_objects[1].id, "zeta")


func test_rejects_unsupported_schema_version() -> void:
	var data := LevelFixtures.corridor()
	data["schema_version"] = 2
	_assert_rejected(data, "schema_version 2 is not supported")


func test_rejects_non_integer_coordinate() -> void:
	var data := LevelFixtures.corridor()
	data["core"]["position"] = [0.5, 1]
	_assert_rejected(data, "core.position[0] must be an integer")


func test_rejects_missing_required_field() -> void:
	var data := LevelFixtures.corridor()
	data.erase("board")
	_assert_rejected(data, "board must be an object")


func test_rejects_non_adjacent_route_nodes() -> void:
	var data := LevelFixtures.corridor()
	(data["routes"]["main"]["nodes"] as Array).remove_at(2)
	_assert_rejected(data, "is not orthogonally adjacent")


func test_rejects_route_through_wall() -> void:
	var data := LevelFixtures.corridor()
	data["terrain"]["walls"] = [[2, 1]]
	_assert_rejected(data, "passes through a wall")


func test_rejects_route_out_of_bounds() -> void:
	var data := LevelFixtures.corridor()
	data["board"]["width"] = 5
	_assert_rejected(data, "is out of bounds")


func test_rejects_route_revisiting_a_cell() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["main"]["nodes"] = [[0, 1], [1, 1], [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1]]
	_assert_rejected(data, "revisits a cell")


func test_rejects_core_not_at_route_start() -> void:
	var data := LevelFixtures.corridor()
	data["core"]["position"] = [1, 1]
	_assert_rejected(data, "core.position must equal the first node")


func test_rejects_destination_not_at_route_end() -> void:
	var data := LevelFixtures.corridor()
	data["destination"]["position"] = [5, 1]
	_assert_rejected(data, "destination.position must equal the last node")


func test_rejects_unknown_start_route() -> void:
	var data := LevelFixtures.corridor()
	data["core"]["route_id"] = "missing"
	_assert_rejected(data, "does not name a route")


func test_rejects_multiple_route_segments() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["extra"] = {"nodes": [[0, 2], [1, 2]], "checkpoints": []}
	_assert_rejected(data, "exactly one route segment")


func test_rejects_checkpoint_off_route() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["main"]["checkpoints"][0]["position"] = [3, 0]
	_assert_rejected(data, "is not on its route")


func test_rejects_checkpoint_on_route_end() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["main"]["checkpoints"][0]["position"] = [6, 1]
	_assert_rejected(data, "must not be on the route's first or last node")


func test_rejects_duplicate_checkpoint_ids() -> void:
	var data := LevelFixtures.corridor()
	(data["routes"]["main"]["checkpoints"] as Array).append({"id": "cp", "position": [4, 1]})
	_assert_rejected(data, "duplicate checkpoint id 'cp'")


func test_rejects_unknown_allowed_mechanism() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["main"]["checkpoints"][0]["allowed_mechanisms"] = ["teleport_everything"]
	_assert_rejected(data, "is not a known mechanism")


func test_rejects_object_on_core_start() -> void:
	_assert_rejected(LevelFixtures.corridor_with_blocks([Vector2i(0, 1)]), "must not start on the core's cell")


func test_rejects_overlapping_objects() -> void:
	_assert_rejected(LevelFixtures.corridor_with_blocks([Vector2i(2, 0), Vector2i(2, 0)]), "overlaps another object")


func test_rejects_duplicate_object_ids() -> void:
	var data := LevelFixtures.corridor()
	data["objects"] = [
		{"id": "a", "kind": "block", "position": [2, 0]},
		{"id": "a", "kind": "block", "position": [4, 0]},
	]
	_assert_rejected(data, "duplicate object id 'a'")


func test_rejects_unsupported_object_kind() -> void:
	var data := LevelFixtures.corridor()
	data["objects"] = [{"id": "m", "kind": "magnet", "position": [2, 0]}]
	_assert_rejected(data, "kind 'magnet' is not supported")


func test_rejects_unimplemented_mechanism_content() -> void:
	var data := LevelFixtures.corridor()
	data["mechanisms"] = {"gravity_zones": [{"id": "g"}]}
	_assert_rejected(data, "mechanisms.gravity_zones is not supported by the simulation yet")


func test_rejects_unknown_mechanism_collection() -> void:
	var data := LevelFixtures.corridor()
	data["mechanisms"] = {"lasers": []}
	_assert_rejected(data, "mechanisms.lasers is not a known mechanism collection")


func test_rejects_mismatched_objective_target() -> void:
	var data := LevelFixtures.corridor()
	data["objectives"][0]["target_id"] = "other_seal"
	_assert_rejected(data, "does not match destination.seal_id")


func test_rejects_invalid_access() -> void:
	var data := LevelFixtures.corridor()
	data["access"] = "vip"
	_assert_rejected(data, "access 'vip'")


func test_rejects_invalid_json_text() -> void:
	var result := LevelLoader.parse_text("{ not json", "broken.json")
	assert_null(result.level)
	assert_eq(result.errors.size(), 1)
	assert_true(result.errors[0].begins_with("broken.json: invalid JSON"), str(result.errors))


func test_rejects_missing_file() -> void:
	var result := LevelLoader.load_file("res://data/levels/does_not_exist.json")
	assert_null(result.level)
	assert_true(result.errors.size() == 1 and result.errors[0].contains("file not found"), str(result.errors))


func _assert_rejected(data: Dictionary, expected_fragment: String) -> void:
	var result := LevelLoader.from_dict(data)
	assert_null(result.level, "level should be rejected")
	var found := false
	for message: String in result.errors:
		if message.contains(expected_fragment):
			found = true
	assert_true(found, "expected an error containing '%s', got %s" % [expected_fragment, result.errors])
