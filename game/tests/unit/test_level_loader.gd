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
	assert_eq(level.board_size, Vector2i(7, 9))
	assert_eq(level.core_start, Vector2i(1, 1))
	assert_eq(level.destination, Vector2i(1, 8))
	assert_eq(level.seal_id, "seal_final")
	assert_eq(level.walls.size(), 4)
	assert_true(level.is_wall(Vector2i(5, 2)))
	assert_eq(level.optimal_actions, 0)
	var route := level.routes["route_main"]
	assert_eq(route.nodes.size(), 16)
	assert_eq(route.checkpoints.size(), 1, "the first level: route, core, seal and one checkpoint")
	assert_true(route.checkpoints[0].allowed_mechanisms.is_empty(), "no mechanisms yet")


func test_fixture_is_valid() -> void:
	var result := LevelLoader.from_dict(LevelFixtures.corridor())
	assert_eq(result.errors, PackedStringArray())
	assert_true(result.is_ok())
	if result.is_ok():
		assert_eq(result.level.optimal_actions, -1, "null optimal_actions maps to -1")


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
	_assert_rejected(data, "route 'main' must end at the destination, on a portal entry, or next to one rotating section")


func test_rejects_unknown_start_route() -> void:
	var data := LevelFixtures.corridor()
	data["core"]["route_id"] = "missing"
	_assert_rejected(data, "does not name a route")


func test_rejects_unreachable_route_segment() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["extra"] = {"nodes": [[0, 2], [1, 2]], "checkpoints": []}
	_assert_rejected(data, "route 'extra' must end at the destination, on a portal entry, or next to one rotating section")


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
	data["mechanisms"] = {"push_devices": [{"id": "d"}]}
	_assert_rejected(data, "mechanisms.push_devices is not supported by the simulation yet")


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


# --- M2: gravity zones, object flags, mechanism availability ------------------

## Corridor + column zone "g" at x = 5 pointing up, block "b" resting at its top.
func _zone_data() -> Dictionary:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "b", Vector2i(5, 0))
	return LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])


func test_loads_gravity_zone_object_flags_and_setup() -> void:
	var data := _zone_data()
	LevelFixtures.add_block(data, "fixed", Vector2i(2, 0), false, false)
	LevelFixtures.allow_everywhere(data, [MechanismIds.GRAVITY_SHIFT, MechanismIds.PUSH_PULSE])
	var result := LevelLoader.from_dict(data)
	assert_eq(result.errors, PackedStringArray())
	if not result.is_ok():
		return
	var level := result.level
	assert_eq(level.gravity_zones.size(), 1)
	var zone := level.gravity_zones[0]
	assert_eq(zone.rect, Rect2i(5, 0, 1, 3))
	assert_eq(zone.initial_direction, Grid.Direction.UP)
	assert_eq(zone.allowed_directions, [Grid.Direction.UP, Grid.Direction.DOWN] as Array[Grid.Direction])
	var fixed := level.initial_objects[1]
	assert_eq(fixed.id, "fixed")
	assert_false(fixed.pushable)
	assert_false(fixed.gravity_affected)
	assert_true(level.initial_objects[0].pushable, "flags default to true")
	assert_eq(level.setup_allowed_mechanisms, PackedStringArray(["gravity_shift", "push_pulse"]))


func test_rejects_unsettled_initial_state() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "b", Vector2i(5, 2))
	LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up"])
	_assert_rejected(data, "object 'b' is not at rest under gravity")


func test_rejects_zone_outside_board() -> void:
	var data := LevelFixtures.add_gravity_zone(LevelFixtures.corridor(), "g", Vector2i(5, 0), Vector2i(3, 1), "up", ["up"])
	_assert_rejected(data, "extends outside the board")


func test_rejects_zone_with_zero_size() -> void:
	var data := LevelFixtures.add_gravity_zone(LevelFixtures.corridor(), "g", Vector2i(5, 0), Vector2i(0, 1), "up", ["up"])
	_assert_rejected(data, "must have a positive size")


func test_rejects_overlapping_zones() -> void:
	var data := LevelFixtures.add_gravity_zone(_zone_data(), "h", Vector2i(4, 1), Vector2i(2, 1), "left", ["left"])
	_assert_rejected(data, "gravity zones 'g' and 'h' overlap")


func test_rejects_duplicate_zone_ids() -> void:
	var data := LevelFixtures.add_gravity_zone(_zone_data(), "g", Vector2i(0, 0), Vector2i(1, 1), "up", ["up"])
	_assert_rejected(data, "duplicate gravity zone id 'g'")


func test_rejects_initial_direction_not_allowed() -> void:
	var data := LevelFixtures.add_gravity_zone(LevelFixtures.corridor(), "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["down"])
	_assert_rejected(data, "initial direction must be one of its allowed directions")


func test_rejects_unknown_direction_name() -> void:
	var data := LevelFixtures.add_gravity_zone(LevelFixtures.corridor(), "g", Vector2i(5, 0), Vector2i(1, 3), "north", ["up"])
	_assert_rejected(data, "direction must be one of up, right, down, left")


func test_rejects_zone_without_allowed_directions() -> void:
	var data := LevelFixtures.add_gravity_zone(LevelFixtures.corridor(), "g", Vector2i(5, 0), Vector2i(1, 3), "up", [])
	_assert_rejected(data, "must allow at least one direction")


func test_rejects_unimplemented_allowed_mechanism() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["main"]["checkpoints"][0]["allowed_mechanisms"] = ["portal_network"]
	_assert_rejected(data, "'portal_network' is not supported by the simulation yet")


func test_rejects_duplicate_allowed_mechanism() -> void:
	var data := LevelFixtures.allow_everywhere(_zone_data(), [MechanismIds.GRAVITY_SHIFT, MechanismIds.GRAVITY_SHIFT])
	_assert_rejected(data, "'gravity_shift' is listed twice")


func test_rejects_gravity_allowed_without_zones() -> void:
	var data := LevelFixtures.allow_everywhere(LevelFixtures.corridor(), [MechanismIds.GRAVITY_SHIFT])
	_assert_rejected(data, "setup allows gravity_shift but the level has no gravity zones")


func test_rejects_push_allowed_without_pushable_objects() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "heavy", Vector2i(2, 0), false)
	LevelFixtures.allow_everywhere(data, [MechanismIds.PUSH_PULSE])
	_assert_rejected(data, "checkpoint 'cp' allows push_pulse but the level has no pushable objects")


# --- M5a: switches and gates ------------------------------------------------------

func test_loads_switches_and_gates() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(5, 0), true)
	LevelFixtures.add_switch(data, "p", "pressure", Vector2i(4, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["t", "p"])
	var result := LevelLoader.from_dict(data)
	assert_eq(result.errors, PackedStringArray())
	if not result.is_ok():
		return
	var level := result.level
	assert_eq(level.switches.size(), 2)
	assert_eq(level.switch_by_id("t").kind, SwitchDefinition.Kind.TOGGLE)
	assert_true(level.switch_by_id("t").initially_on)
	assert_eq(level.switch_by_id("p").kind, SwitchDefinition.Kind.PRESSURE)
	assert_eq(level.gate_at(Vector2i(5, 1)).requires, PackedStringArray(["t", "p"]))
	assert_true(level.create_initial_state().toggle_states["t"])


func test_rejects_gate_requiring_unknown_switch() -> void:
	_assert_rejected(LevelFixtures.add_gate(LevelFixtures.corridor(), "g", Vector2i(5, 1), ["ghost"]),
		"gate 'g' requires unknown switch 'ghost'")


func test_rejects_gate_without_switches() -> void:
	_assert_rejected(LevelFixtures.add_gate(LevelFixtures.corridor(), "g", Vector2i(5, 1), []),
		"gate 'g' must require at least one switch")


func test_rejects_unknown_switch_kind() -> void:
	_assert_rejected(LevelFixtures.add_switch(LevelFixtures.corridor(), "s", "lever", Vector2i(5, 0)),
		"kind 'lever' must be pressure, toggle or receiver")


func test_rejects_initially_on_for_pressure_switch() -> void:
	var data := LevelFixtures.corridor()
	data["mechanisms"] = {"switches": [{"id": "p", "kind": "pressure", "position": [5, 0], "initially_on": true}]}
	_assert_rejected(data, "initially_on only applies to toggle switches")


func test_rejects_gate_on_a_switch() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(5, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 0), ["t"])
	_assert_rejected(data, "gate 'g' shares a cell with a switch")


func test_rejects_duplicate_switch_and_gate_ids() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "x", "toggle", Vector2i(5, 0))
	LevelFixtures.add_gate(data, "x", Vector2i(5, 1), ["x"])
	_assert_rejected(data, "duplicate switch or gate id 'x'")


func test_rejects_gate_starting_closed_on_a_block() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(5, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(4, 2), ["t"])
	LevelFixtures.add_block(data, "b", Vector2i(4, 2))
	_assert_rejected(data, "gate 'g' starts closed on an occupied cell")


func test_rejects_switches_allowed_without_toggle_switch() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "p", "pressure", Vector2i(4, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["p"])
	LevelFixtures.allow_everywhere(data, [MechanismIds.SWITCHES_SEALS])
	_assert_rejected(data, "allows switches_seals but the level has no toggle switches")


func _assert_rejected(data: Dictionary, expected_fragment: String) -> void:
	var result := LevelLoader.from_dict(data)
	assert_null(result.level, "level should be rejected")
	var found := false
	for message: String in result.errors:
		if message.contains(expected_fragment):
			found = true
	assert_true(found, "expected an error containing '%s', got %s" % [expected_fragment, result.errors])
