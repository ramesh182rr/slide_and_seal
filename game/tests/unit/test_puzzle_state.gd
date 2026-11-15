extends TestCase
## PuzzleState: initial state, cloning and canonical keys.


func test_initial_state_matches_level() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 0)]))
	var state := level.create_initial_state()
	assert_eq(state.phase, PuzzleState.Phase.SETUP)
	assert_eq(state.core_route_id, "main")
	assert_eq(state.core_node_index, 0)
	assert_eq(PuzzleSimulator.core_position(level, state), level.core_start)
	assert_eq(state.objects.size(), 1)
	assert_true(state.objects[0] != level.initial_objects[0], "objects are copies, not shared with the level")
	assert_eq(state.objects[0].position, Vector2i(2, 0))
	assert_eq(state.reached_checkpoint_ids.size(), 0)


func test_initial_states_are_equal_but_independent() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 0)]))
	var a := level.create_initial_state()
	var b := level.create_initial_state()
	assert_eq(a.to_key(), b.to_key())
	b.objects[0].position = Vector2i(4, 0)
	assert_eq(a.objects[0].position, Vector2i(2, 0))


func test_clone_is_deep_and_independent() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 0)]))
	var original := level.create_initial_state()
	var key_before := original.to_key()
	var copy := original.clone()
	assert_eq(copy.to_key(), key_before)
	copy.objects[0].position = Vector2i(5, 0)
	copy.reached_checkpoint_ids.append("cp")
	copy.core_node_index = 3
	assert_eq(original.to_key(), key_before, "mutating the clone must not affect the original")


func test_key_changes_when_any_field_changes() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 0)]))
	var base := level.create_initial_state()
	var mutations: Dictionary[String, Callable] = {
		"phase": func(s: PuzzleState) -> void: s.phase = PuzzleState.Phase.CHECKPOINT_PAUSED,
		"core_route_id": func(s: PuzzleState) -> void: s.core_route_id = "other",
		"core_node_index": func(s: PuzzleState) -> void: s.core_node_index = 1,
		"object position": func(s: PuzzleState) -> void: s.objects[0].position = Vector2i(4, 0),
		"object kind": func(s: PuzzleState) -> void: s.objects[0].kind = "other",
		"object pushable": func(s: PuzzleState) -> void: s.objects[0].pushable = false,
		"object gravity_affected": func(s: PuzzleState) -> void: s.objects[0].gravity_affected = false,
		"gravity direction": func(s: PuzzleState) -> void: s.gravity_directions["g"] = Grid.Direction.LEFT,
		"reached checkpoints": func(s: PuzzleState) -> void: s.reached_checkpoint_ids.append("cp"),
		"mechanism_action_count": func(s: PuzzleState) -> void: s.mechanism_action_count = 1,
		"core_run_count": func(s: PuzzleState) -> void: s.core_run_count = 1,
	}
	for field: String in mutations.keys():
		var changed := base.clone()
		mutations[field].call(changed)
		assert_ne(changed.to_key(), base.to_key(), "key must change when %s changes" % field)


func test_initial_state_has_zone_directions_and_clone_copies_them() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "b", Vector2i(5, 0))
	LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])
	var level := LevelFixtures.build(data)
	var state := level.create_initial_state()
	assert_eq(state.gravity_directions["g"], Grid.Direction.UP)
	var copy := state.clone()
	copy.gravity_directions["g"] = Grid.Direction.DOWN
	assert_eq(state.gravity_directions["g"], Grid.Direction.UP, "clone must not share the direction map")


func test_object_at_finds_objects() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 0)]))
	var state := level.create_initial_state()
	assert_not_null(state.object_at(Vector2i(2, 0)))
	assert_null(state.object_at(Vector2i(3, 0)))
