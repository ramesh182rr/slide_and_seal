extends TestCase
## Rotating Sections (decisions D-017 – D-020). Fixture: LevelFixtures.rotation_corridor().

const ROTATE := MechanismIds.ROTATING_SECTIONS
const PUSH := MechanismIds.PUSH_PULSE


func _level(data: Dictionary) -> LevelDefinition:
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func _apply(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	return PuzzleSimulator.apply_action(level, state, action)


## Runs to the checkpoint, then on to the end of segment "a" (waiting beside the section).
func _waiting_at_section(level: LevelDefinition) -> PuzzleState:
	var paused := _apply(level, level.create_initial_state(), PuzzleAction.run_core()).state
	return _apply(level, paused, PuzzleAction.run_core()).state


func test_cell_rotation_is_a_quarter_turn_and_inverts() -> void:
	var section := RotatingSectionDefinition.new()
	section.origin = Vector2i(3, 1)
	section.size = 3
	assert_eq(section.rotate_cell(Vector2i(4, 1), 1), Vector2i(5, 2), "top-middle → right-middle (clockwise)")
	assert_eq(section.rotate_cell(Vector2i(3, 1), 1), Vector2i(5, 1), "top-left corner → top-right")
	assert_eq(section.rotate_cell(Vector2i(4, 2), 3), Vector2i(4, 2), "the centre never moves")
	assert_eq(section.rotate_cell(Vector2i(3, 3), 4), Vector2i(3, 3), "four turns are identity")
	for cell: Vector2i in [Vector2i(3, 1), Vector2i(5, 3), Vector2i(4, 1)]:
		for turns: int in 4:
			assert_eq(section.authored_cell(section.rotate_cell(cell, turns), turns), cell)


func test_core_waits_where_the_track_does_not_line_up() -> void:
	var level := _level(LevelFixtures.rotation_corridor())
	var paused := _apply(level, level.create_initial_state(), PuzzleAction.run_core()).state
	var result := _apply(level, paused, PuzzleAction.run_core())
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(PuzzleSimulator.core_position(level, result.state), Vector2i(2, 2))
	assert_eq(result.travel.blocked_cell, Vector2i(3, 2), "the cell the core was heading into")


func test_clockwise_turn_connects_and_track_is_travelled_in_reverse() -> void:
	var level := _level(LevelFixtures.rotation_corridor())
	var turned := _apply(level, _waiting_at_section(level), PuzzleAction.rotate_section("s", true))
	assert_true(turned.is_ok(), turned.message)
	assert_eq(turned.state.section_turns["s"], 1)
	assert_eq(turned.state.mechanism_action_count, 1)
	var result := _apply(level, turned.state, PuzzleAction.run_core())
	assert_true(result.is_ok(), result.message)
	assert_eq(result.travel.path,
		[Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4)] as Array[Vector2i])
	assert_eq(result.state.phase, PuzzleState.Phase.LEVEL_COMPLETED)


func test_counterclockwise_turn_connects_forwards() -> void:
	var level := _level(LevelFixtures.rotation_corridor())
	var turned := _apply(level, _waiting_at_section(level), PuzzleAction.rotate_section("s", false)).state
	assert_eq(turned.section_turns["s"], 3)
	var result := _apply(level, turned, PuzzleAction.run_core())
	assert_eq(result.state.phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(result.travel.path[0], Vector2i(3, 2))


func test_cannot_turn_while_core_is_inside() -> void:
	# D-021 keeps the core out of sections during normal play, so build the state directly
	# to exercise the D-019 safeguard.
	var level := _level(LevelFixtures.rotation_corridor())
	var inside := level.create_initial_state()
	inside.phase = PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION
	inside.core_route_id = "t"
	inside.core_node_index = 1
	assert_eq(PuzzleSimulator.core_position(level, inside), Vector2i(4, 2))
	assert_eq(_apply(level, inside, PuzzleAction.rotate_section("s", true)).failure,
		ActionResult.Failure.MOVE_BLOCKED)


# --- D-021: only enter a track piece the core can pass straight through -----------

func test_core_waits_outside_when_exit_corridor_is_blocked() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.rotation_corridor(), "k", Vector2i(6, 2))
	var level := _level(data)
	var turned := _apply(level, _waiting_at_section(level), PuzzleAction.rotate_section("s", true)).state
	var result := _apply(level, turned, PuzzleAction.run_core())
	assert_eq(result.failure, ActionResult.Failure.ROUTE_BLOCKED, "the piece lines up, but the exit is blocked")
	assert_eq(PuzzleSimulator.core_position(level, turned), Vector2i(2, 2), "the core stays outside the section")


func test_core_waits_outside_when_a_block_sits_on_the_piece() -> void:
	# A crate on the centre cell lies on the piece in every orientation.
	var data := LevelFixtures.add_block(LevelFixtures.rotation_corridor(), "k", Vector2i(4, 2))
	var level := _level(data)
	var paused := _apply(level, level.create_initial_state(), PuzzleAction.run_core()).state
	var turned := _apply(level, paused, PuzzleAction.rotate_section("s", true)).state
	var result := _apply(level, turned, PuzzleAction.run_core())
	assert_eq(result.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(PuzzleSimulator.core_position(level, result.state), Vector2i(2, 2))
	assert_eq(result.travel.blocked_cell, Vector2i(3, 2), "reported at the piece's near end")


func test_quarter_turn_overshoot_no_longer_strands_the_core() -> void:
	# Regression: three turns leave the L joined to the incoming corridor only. Before D-021 the core
	# ran in and stranded inside the turntable; now it waits outside, still free to turn the table on
	# round to the connecting orientation (turn 2 = three more clockwise turns from turn 3).
	var level := LevelLoader.load_file("res://data/levels/world_06_quarter_turn.json").level
	var state := _apply(level, level.create_initial_state(), PuzzleAction.run_core()).state
	for i: int in 3:
		state = _apply(level, state, PuzzleAction.rotate_section("turntable", true)).state
	var waiting := _apply(level, state, PuzzleAction.run_core())
	assert_eq(waiting.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(PuzzleSimulator.core_position(level, waiting.state), Vector2i(2, 3), "outside the turntable")
	var fixed := waiting.state
	for i: int in 3:
		fixed = _apply(level, fixed, PuzzleAction.rotate_section("turntable", true)).state
	assert_eq(fixed.section_turns["turntable"], 2)
	assert_eq(_apply(level, fixed, PuzzleAction.run_core()).state.phase, PuzzleState.Phase.LEVEL_COMPLETED)


func test_walls_inside_turn_with_the_section() -> void:
	var data := LevelFixtures.rotation_corridor()
	data["terrain"]["walls"] = [[5, 1]]
	var level := _level(data)
	var state := level.create_initial_state()
	assert_true(PuzzleSimulator.is_wall_at(level, state, Vector2i(5, 1)))
	var turned := _apply(level, state, PuzzleAction.rotate_section("s", true)).state
	assert_false(PuzzleSimulator.is_wall_at(level, turned, Vector2i(5, 1)))
	assert_true(PuzzleSimulator.is_wall_at(level, turned, Vector2i(5, 3)), "top-right corner → bottom-right")


func test_blocks_inside_turn_with_the_section() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.rotation_corridor(), "k", Vector2i(3, 1))
	var level := _level(data)
	var result := _apply(level, level.create_initial_state(), PuzzleAction.rotate_section("s", true))
	assert_eq(result.state.object_by_id("k").position, Vector2i(5, 1))
	assert_eq(result.object_moves.size(), 1)
	assert_eq(result.object_moves[0].cause, ObjectMove.Cause.ROTATION)


func test_blocks_outside_are_untouched() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.rotation_corridor(), "k", Vector2i(2, 0))
	var level := _level(data)
	var result := _apply(level, level.create_initial_state(), PuzzleAction.rotate_section("s", true))
	assert_eq(result.state.object_by_id("k").position, Vector2i(2, 0))


func test_pushes_respect_turned_walls() -> void:
	var data := LevelFixtures.rotation_corridor()
	data["terrain"]["walls"] = [[3, 1]]
	LevelFixtures.add_block(data, "k", Vector2i(6, 0))
	var level := _level(LevelFixtures.allow_everywhere(data, [ROTATE, PUSH]))
	var state := level.create_initial_state()
	assert_true(_apply(level, state, PuzzleAction.push("k", Grid.Direction.LEFT)).is_ok(), "(5,0) is outside, free")
	var turned := _apply(level, state, PuzzleAction.rotate_section("s", true)).state  # wall (3,1) → (5,1)
	assert_true(PuzzleSimulator.is_wall_at(level, turned, Vector2i(5, 1)))
	var into_wall := _apply(level, turned, PuzzleAction.push("k", Grid.Direction.DOWN))
	assert_true(into_wall.is_ok(), "(6,1) is outside the section and free")
	assert_eq(_apply(level, into_wall.state, PuzzleAction.push("k", Grid.Direction.LEFT)).failure,
		ActionResult.Failure.MOVE_BLOCKED, "the turned wall now sits at (5,1)")


func test_rejects_disallowed_direction_unknown_section_and_unavailable_mechanism() -> void:
	var data := LevelFixtures.rotation_corridor()
	data["mechanisms"]["rotating_sections"][0]["allowed_directions"] = ["clockwise"]
	var level := _level(data)
	var state := level.create_initial_state()
	assert_eq(_apply(level, state, PuzzleAction.rotate_section("s", false)).failure, ActionResult.Failure.INVALID_DIRECTION)
	assert_eq(_apply(level, state, PuzzleAction.rotate_section("nope", true)).failure, ActionResult.Failure.INVALID_TARGET)
	var locked := LevelFixtures.rotation_corridor()
	LevelFixtures.allow_everywhere(locked, [])
	var locked_level := _level(locked)
	assert_eq(_apply(locked_level, locked_level.create_initial_state(), PuzzleAction.rotate_section("s", true)).failure,
		ActionResult.Failure.MECHANISM_NOT_ALLOWED)


func test_four_turns_return_to_the_same_board() -> void:
	var level := _level(LevelFixtures.add_block(LevelFixtures.rotation_corridor(), "k", Vector2i(3, 1)))
	var start := level.create_initial_state()
	var state := start
	for i: int in 4:
		state = _apply(level, state, PuzzleAction.rotate_section("s", true)).state
	assert_eq(state.to_key(false), start.to_key(false))
	assert_eq(state.mechanism_action_count, 4)


func test_undo_restores_turns_and_travel() -> void:
	var session := PuzzleSession.new(_level(LevelFixtures.rotation_corridor()))
	session.apply(PuzzleAction.run_core())
	session.apply(PuzzleAction.run_core())
	session.apply(PuzzleAction.rotate_section("s", true))
	var before_run := session.get_state().to_key()
	assert_true(session.apply(PuzzleAction.run_core()).is_ok())
	assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), before_run)
	assert_true(session.undo())
	assert_eq(session.get_state().section_turns["s"], 0)


func test_preview_matches_apply() -> void:
	var level := _level(LevelFixtures.rotation_corridor())
	var state := _waiting_at_section(level)
	var key := state.to_key()
	var action := PuzzleAction.rotate_section("s", true)
	var preview := PuzzleSimulator.preview_action(level, state, action)
	assert_eq(state.to_key(), key)
	assert_eq(preview.state.to_key(), _apply(level, state, action).state.to_key())


func test_solver_finds_single_turn() -> void:
	var result := PuzzleSolver.solve(_level(LevelFixtures.rotation_corridor()))
	assert_true(result.solvable)
	assert_eq(result.minimum_actions, 1)


# --- Loader -----------------------------------------------------------------------

func _assert_rejected(data: Dictionary, fragment: String) -> void:
	var result := LevelLoader.from_dict(data)
	assert_null(result.level, "level should be rejected")
	var found := false
	for message: String in result.errors:
		found = found or message.contains(fragment)
	assert_true(found, "expected an error containing '%s', got %s" % [fragment, result.errors])


func test_loader_marks_track_pieces() -> void:
	var level := _level(LevelFixtures.rotation_corridor())
	assert_eq(level.routes["t"].section_id, "s")
	assert_eq(level.routes["a"].section_id, "")
	assert_eq(level.rotating_sections[0].size, 3)
	assert_true(level.rotating_sections[0].allow_counterclockwise)


func test_rejects_tiny_section() -> void:
	var data := LevelFixtures.rotation_corridor()
	data["mechanisms"]["rotating_sections"][0]["size"] = 1
	_assert_rejected(data, "must be at least 2x2")


func test_rejects_section_outside_board() -> void:
	var data := LevelFixtures.rotation_corridor()
	data["mechanisms"]["rotating_sections"][0]["position"] = [5, 1]
	_assert_rejected(data, "extends outside the board")


func test_rejects_route_partly_inside_a_section() -> void:
	var data := LevelFixtures.rotation_corridor()
	data["routes"]["b"]["nodes"] = [[5, 2], [6, 2], [6, 3], [6, 4]]
	_assert_rejected(data, "route 'b' must lie entirely inside one rotating section or entirely outside")


func test_rejects_checkpoint_inside_a_section() -> void:
	var data := LevelFixtures.rotation_corridor()
	data["routes"]["t"]["checkpoints"] = [{"id": "inner", "position": [4, 2]}]
	_assert_rejected(data, "checkpoint 'inner' inside rotating section 's' is not supported yet")


func test_rejects_switch_inside_a_section() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.rotation_corridor(), "t1", "toggle", Vector2i(3, 3))
	_assert_rejected(data, "switch 't1' inside rotating section 's' is not supported yet")


func test_rejects_section_overlapping_gravity_zone() -> void:
	var data := LevelFixtures.add_gravity_zone(LevelFixtures.rotation_corridor(), "z", Vector2i(5, 0), Vector2i(1, 2), "up", ["up"])
	_assert_rejected(data, "rotating section 's' overlaps gravity zone 'z'")


func test_rejects_unreachable_track_piece() -> void:
	var data := LevelFixtures.rotation_corridor()
	LevelFixtures.add_rotating_section(data, "far", Vector2i(0, 3), 2, ["clockwise"])
	data["routes"]["lost"] = {"nodes": [[0, 3], [1, 3]], "checkpoints": []}
	_assert_rejected(data, "track piece 'lost' is never reached")


func test_rejects_well_formed_but_unreachable_segment() -> void:
	# "u" starts beside section "far" (which no route end touches) and ends beside section "s".
	var data := LevelFixtures.rotation_corridor()
	LevelFixtures.add_rotating_section(data, "far", Vector2i(0, 0), 2, ["clockwise"])
	data["routes"]["u"] = {"nodes": [[2, 0], [3, 0]], "checkpoints": []}
	_assert_rejected(data, "route segment 'u' is never reached from the start")
