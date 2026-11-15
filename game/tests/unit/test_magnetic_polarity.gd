extends TestCase
## Magnetic Polarity (decisions D-026 – D-029). Fixture: LevelFixtures.magnet_corridor():
## magnet "m" at (3,0); flipping it switches its polarity and fires one pulse.

const MAGNET := MechanismIds.MAGNETIC_POLARITY
const PUSH := MechanismIds.PUSH_PULSE


func _level(data: Dictionary) -> LevelDefinition:
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func _flip(level: LevelDefinition, state: PuzzleState = null) -> ActionResult:
	return PuzzleSimulator.apply_action(level, state if state != null else level.create_initial_state(),
		PuzzleAction.flip_magnet("m"))


func _position(result: ActionResult, object_id: String) -> Vector2i:
	return result.state.object_by_id(object_id).position


func test_opposite_polarity_attracts_one_cell() -> void:
	# Magnet starts "-", flips to "+"; block "-" two cells right is attracted one step.
	var level := _level(LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(5, 0), "-"))
	var result := _flip(level)
	assert_true(result.is_ok(), result.message)
	assert_true(result.state.magnet_positive["m"])
	assert_eq(_position(result, "b"), Vector2i(4, 0))
	assert_eq(result.object_moves.size(), 1)
	assert_eq(result.object_moves[0].cause, ObjectMove.Cause.MAGNET)
	assert_eq(result.state.mechanism_action_count, 1)


func test_like_polarity_repels_one_cell() -> void:
	var level := _level(LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(5, 0), "+"))
	assert_eq(_position(_flip(level), "b"), Vector2i(6, 0))


func test_flipping_back_reverses_the_force() -> void:
	var level := _level(LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(5, 0), "-"))
	var once := _flip(level)
	assert_eq(_position(once, "b"), Vector2i(4, 0), "attracted")
	assert_eq(_position(_flip(level, once.state), "b"), Vector2i(5, 0), "magnet is now '-': repelled")


func test_adjacent_attracted_block_cannot_enter_the_magnet() -> void:
	var level := _level(LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(4, 0), "-"))
	var result := _flip(level)
	assert_true(result.is_ok(), "flipping still succeeds")
	assert_eq(_position(result, "b"), Vector2i(4, 0))
	assert_eq(result.object_moves.size(), 0)


func test_repelled_block_stops_at_the_board_edge() -> void:
	var level := _level(LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(6, 0), "+"))
	assert_eq(_position(_flip(level), "b"), Vector2i(6, 0))


func test_neutral_block_shields_the_line() -> void:
	# Unshielded, "b" (+) would be repelled from (5,0) to the free cell (6,0).
	var data := LevelFixtures.add_block(LevelFixtures.magnet_corridor("-"), "n", Vector2i(4, 0))
	LevelFixtures.add_polar_block(data, "b", Vector2i(5, 0), "+")
	var result := _flip(_level(data))
	assert_eq(_position(result, "n"), Vector2i(4, 0))
	assert_eq(_position(result, "b"), Vector2i(5, 0), "shielded by the neutral block")


func test_only_the_first_polarised_block_per_line_moves() -> void:
	# "a" (-) is attracted from (5,0) to (4,0). Unshielded, "b" (-) would then follow into (5,0).
	var data := LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "a", Vector2i(5, 0), "-")
	LevelFixtures.add_polar_block(data, "b", Vector2i(6, 0), "-")
	var result := _flip(_level(data))
	assert_eq(_position(result, "a"), Vector2i(4, 0))
	assert_eq(_position(result, "b"), Vector2i(6, 0), "b is shielded by a")


func test_walls_stop_the_field() -> void:
	var data := LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(5, 0), "-")
	data["terrain"]["walls"] = [[4, 0]]
	assert_eq(_position(_flip(_level(data)), "b"), Vector2i(5, 0))


func test_all_four_lines_act_in_one_pulse() -> void:
	var data := LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "east", Vector2i(5, 0), "-")
	LevelFixtures.add_polar_block(data, "west", Vector2i(1, 0), "-")
	LevelFixtures.add_polar_block(data, "south", Vector2i(3, 1), "+")
	var result := _flip(_level(data))
	assert_eq(_position(result, "east"), Vector2i(4, 0))
	assert_eq(_position(result, "west"), Vector2i(2, 0))
	assert_eq(_position(result, "south"), Vector2i(3, 2), "repelled down onto the empty route cell")
	assert_eq(result.object_moves.size(), 3)


func test_field_passes_the_core_but_blocks_cannot_move_onto_it() -> void:
	# The core pauses at (3,2) on the magnet's column. "near" (+) at (3,1) would be repelled onto
	# the core: refused, it stays. "far" (+) at (3,3), beyond the core, is reached and repelled.
	var data := LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "near", Vector2i(3, 1), "+")
	var level := _level(data)
	var paused := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.run_core()).state
	assert_eq(PuzzleSimulator.core_position(level, paused), Vector2i(3, 2))
	assert_eq(_position(_flip(level, paused), "near"), Vector2i(3, 1))
	var far_data := LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "far", Vector2i(3, 3), "+")
	var far_level := _level(far_data)
	var far_paused := PuzzleSimulator.apply_action(far_level, far_level.create_initial_state(), PuzzleAction.run_core()).state
	assert_eq(_position(_flip(far_level, far_paused), "far"), Vector2i(3, 4), "the field passes over the core")


func test_pulse_only_no_continuous_pull() -> void:
	var data := LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(5, 0), "-")
	var level := _level(LevelFixtures.allow_everywhere(data, [MAGNET, PUSH]))
	var attracted := _flip(level).state
	var pushed := PuzzleSimulator.apply_action(level, attracted, PuzzleAction.push("b", Grid.Direction.RIGHT))
	assert_true(pushed.is_ok())
	assert_eq(pushed.state.object_by_id("b").position, Vector2i(5, 0), "nothing pulls it back after the push")


func test_magnet_is_solid_and_stops_beams() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.magnet_corridor("-"), "k", Vector2i(4, 0))
	LevelFixtures.add_emitter(data, "e", Vector2i(0, 0), "right")
	var level := _level(LevelFixtures.allow_everywhere(data, [MAGNET, PUSH]))
	var state := level.create_initial_state()
	assert_eq(PuzzleSimulator.apply_action(level, state, PuzzleAction.push("k", Grid.Direction.LEFT)).failure,
		ActionResult.Failure.MOVE_BLOCKED)
	var beam: EnergyResolver.Beam = EnergyResolver.trace(level, state)[0]
	assert_eq(beam.cells, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], "the beam stops before the magnet")


func test_rejections() -> void:
	var level := _level(LevelFixtures.magnet_corridor())
	assert_eq(PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.flip_magnet("nope")).failure,
		ActionResult.Failure.INVALID_TARGET)
	var locked := LevelFixtures.magnet_corridor()
	LevelFixtures.allow_everywhere(locked, [])
	var locked_level := _level(locked)
	assert_eq(_flip(locked_level).failure, ActionResult.Failure.MECHANISM_NOT_ALLOWED)


func test_undo_preview_and_key() -> void:
	var level := _level(LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(5, 0), "-"))
	var session := PuzzleSession.new(level)
	var before := session.get_state().to_key()
	var preview := session.preview(PuzzleAction.flip_magnet("m"))
	assert_eq(session.get_state().to_key(), before)
	session.apply(PuzzleAction.flip_magnet("m"))
	assert_eq(session.get_state().to_key(), preview.state.to_key())
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), before)
	var neutral := _level(LevelFixtures.add_block(LevelFixtures.magnet_corridor("-"), "b", Vector2i(5, 0)))
	assert_ne(level.create_initial_state().to_key(false), neutral.create_initial_state().to_key(false),
		"block polarity is part of the key")


func test_solver_attracts_a_block_off_the_route() -> void:
	# Block "+" sits on the route at (5,2), below magnet "m" (5,0) "+". Flipping the magnet to "-"
	# attracts it up to (5,1), clearing the route.
	var data := LevelFixtures.magnet_corridor("-")
	data["mechanisms"]["magnetic_fields"] = []
	LevelFixtures.add_magnet(data, "m", Vector2i(5, 0), "+")
	LevelFixtures.add_polar_block(data, "b", Vector2i(5, 2), "+")
	var result := PuzzleSolver.solve(_level(data))
	assert_true(result.solvable)
	assert_eq(result.minimum_actions, 1, "one flip attracts the block up, off the route")


# --- Loader ------------------------------------------------------------------------

func _assert_rejected(data: Dictionary, fragment: String) -> void:
	var result := LevelLoader.from_dict(data)
	assert_null(result.level, "level should be rejected")
	var found := false
	for message: String in result.errors:
		found = found or message.contains(fragment)
	assert_true(found, "expected an error containing '%s', got %s" % [fragment, result.errors])


func test_rejects_bad_magnet_polarity() -> void:
	var data := LevelFixtures.magnet_corridor()
	data["mechanisms"]["magnetic_fields"][0]["polarity"] = "north"
	_assert_rejected(data, "polarity must be")


func test_rejects_bad_block_polarity() -> void:
	_assert_rejected(LevelFixtures.add_polar_block(LevelFixtures.magnet_corridor(), "b", Vector2i(5, 0), "0"),
		"objects[0].polarity must be")


func test_rejects_magnetic_objects_collection() -> void:
	var data := LevelFixtures.magnet_corridor()
	data["mechanisms"]["magnetic_objects"] = [{"id": "x"}]
	_assert_rejected(data, "give blocks a \"polarity\"")


func test_rejects_magnet_on_route() -> void:
	_assert_rejected(LevelFixtures.add_magnet(LevelFixtures.magnet_corridor(), "m2", Vector2i(4, 2), "+"),
		"magnet 'm2' at (4, 2) must not be on a route")


func test_rejects_magnetism_allowed_without_magnets() -> void:
	var data := LevelFixtures.magnet_corridor()
	data["mechanisms"]["magnetic_fields"] = []
	_assert_rejected(data, "allows magnetic_polarity but the level has no magnets")
