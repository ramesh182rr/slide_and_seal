extends TestCase
## Portal Network (decision D-015, core only). Fixture: LevelFixtures.portal_corridor():
## segment "a" (0,1)→(2,1) ends on entry "p_in"; segment "b" (4,1)→(6,1) starts on exit "p_out";
## a wall column at x = 3 separates them; checkpoint "cp" at (5,1).

const PUSH := MechanismIds.PUSH_PULSE
const SWITCHES := MechanismIds.SWITCHES_SEALS


func _level(data: Dictionary) -> LevelDefinition:
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func _run(level: LevelDefinition, state: PuzzleState) -> ActionResult:
	return PuzzleSimulator.apply_action(level, state, PuzzleAction.run_core())


func test_core_teleports_without_resting_on_entry() -> void:
	var level := _level(LevelFixtures.portal_corridor())
	var result := _run(level, level.create_initial_state())
	assert_true(result.is_ok(), result.message)
	assert_eq(result.travel.path, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i])
	assert_eq(result.travel.portal_steps, PackedInt32Array([2]), "path[2] (the exit) was reached by teleport")
	assert_eq(result.state.core_route_id, "b")
	assert_eq(PuzzleSimulator.core_position(level, result.state), Vector2i(5, 1))
	assert_eq(result.travel.stop_reason, CoreTravelResult.StopReason.CHECKPOINT)


func test_resume_completes_on_second_segment() -> void:
	var level := _level(LevelFixtures.portal_corridor())
	var paused := _run(level, level.create_initial_state()).state
	var result := _run(level, paused)
	assert_eq(result.state.phase, PuzzleState.Phase.LEVEL_COMPLETED)


func test_occupied_exit_blocks_the_entry() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.portal_corridor(), "b0", Vector2i(4, 1))
	var level := _level(LevelFixtures.allow_everywhere(data, [PUSH]))
	var result := _run(level, level.create_initial_state())
	assert_eq(result.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(PuzzleSimulator.core_position(level, result.state), Vector2i(1, 1), "the core waits before the entry")
	assert_eq(result.travel.blocked_cell, Vector2i(2, 1))
	var cleared := PuzzleSimulator.apply_action(level, result.state, PuzzleAction.push("b0", Grid.Direction.UP)).state
	var through := _run(level, cleared)
	assert_true(through.is_ok(), through.message)
	assert_eq(through.state.core_route_id, "b")


func test_occupied_entry_blocks_like_any_route_cell() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.portal_corridor(), "b0", Vector2i(2, 1))
	var level := _level(data)
	var result := _run(level, level.create_initial_state())
	assert_eq(result.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(result.travel.blocked_cell, Vector2i(2, 1))


func test_inactive_portal_blocks_until_its_switch_is_on() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.portal_corridor(["t"]), "t", "toggle", Vector2i(0, 0))
	var level := _level(LevelFixtures.allow_everywhere(data, [SWITCHES]))
	var blocked := _run(level, level.create_initial_state())
	assert_eq(blocked.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(blocked.travel.blocked_cell, Vector2i(2, 1))
	var on := PuzzleSimulator.apply_action(level, blocked.state, PuzzleAction.toggle_switch("t")).state
	var through := _run(level, on)
	assert_true(through.is_ok(), through.message)
	assert_eq(through.state.core_route_id, "b")


func test_blocks_treat_portal_cells_as_floor() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.portal_corridor(), "b0", Vector2i(4, 0))
	var level := _level(LevelFixtures.allow_everywhere(data, [PUSH]))
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.push("b0", Grid.Direction.DOWN))
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.object_by_id("b0").position, Vector2i(4, 1), "no teleport for blocks (D-015)")


func test_undo_restores_route_segment() -> void:
	var session := PuzzleSession.new(_level(LevelFixtures.portal_corridor()))
	var before := session.get_state().to_key()
	session.apply(PuzzleAction.run_core())
	assert_eq(session.get_state().core_route_id, "b")
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), before)
	assert_eq(session.get_state().core_route_id, "a")


func test_preview_matches_apply() -> void:
	var level := _level(LevelFixtures.portal_corridor())
	var state := level.create_initial_state()
	var key := state.to_key()
	var preview := PuzzleSimulator.preview_action(level, state, PuzzleAction.run_core())
	assert_eq(state.to_key(), key)
	assert_eq(preview.state.to_key(), _run(level, state).state.to_key())
	assert_eq(preview.travel.portal_steps, PackedInt32Array([2]))


func test_solver_handles_portal_switch() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.portal_corridor(["t"]), "t", "toggle", Vector2i(0, 0))
	var result := PuzzleSolver.solve(_level(LevelFixtures.allow_everywhere(data, [SWITCHES])))
	assert_true(result.solvable)
	assert_eq(result.minimum_actions, 1)


# --- Loader --------------------------------------------------------------------

func test_loader_links_segments() -> void:
	var level := _level(LevelFixtures.portal_corridor())
	assert_eq(level.routes["a"].exit_portal_id, "p_in")
	assert_eq(level.routes["a"].next_route_id, "b")
	assert_eq(level.routes["b"].next_route_id, "")


func _assert_rejected(data: Dictionary, fragment: String) -> void:
	var result := LevelLoader.from_dict(data)
	assert_null(result.level, "level should be rejected")
	var found := false
	for message: String in result.errors:
		found = found or message.contains(fragment)
	assert_true(found, "expected an error containing '%s', got %s" % [fragment, result.errors])


func test_rejects_unknown_exit_portal() -> void:
	var data := LevelFixtures.portal_corridor()
	data["mechanisms"]["portals"][0]["exit"] = "nowhere"
	_assert_rejected(data, "portal 'p_in' exits to unknown portal 'nowhere'")


func test_rejects_portal_exiting_to_itself() -> void:
	var data := LevelFixtures.portal_corridor()
	data["mechanisms"]["portals"][0]["exit"] = "p_in"
	_assert_rejected(data, "portal 'p_in' cannot exit to itself")


func test_rejects_exit_where_no_segment_starts() -> void:
	var data := LevelFixtures.portal_corridor()
	data["mechanisms"]["portals"][1]["position"] = [5, 2]
	_assert_rejected(data, "portal 'p_in' exits at (5, 2), where no route segment starts")


func test_rejects_segment_ending_nowhere() -> void:
	var data := LevelFixtures.portal_corridor()
	data["mechanisms"]["portals"].remove_at(0)
	_assert_rejected(data, "route 'a' must end at the destination or on a portal entry")


func test_rejects_portal_inside_a_segment() -> void:
	var data := LevelFixtures.add_portal(LevelFixtures.portal_corridor(), "p_mid", Vector2i(1, 1))
	_assert_rejected(data, "portal 'p_mid' lies inside route 'a'")


func test_rejects_portal_on_switch_cell() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.portal_corridor(), "t", "toggle", Vector2i(2, 1))
	_assert_rejected(data, "portal 'p_in' shares a cell with a switch")


func test_rejects_cell_shared_between_segments() -> void:
	# Segment b loops over the top row back into (1,1), a cell already used by segment a.
	var data := LevelFixtures.portal_corridor()
	data["terrain"]["walls"] = [[3, 1], [3, 2]]
	data["routes"]["b"]["nodes"] = [[4, 1], [4, 0], [3, 0], [2, 0], [1, 0], [1, 1]]
	data["routes"]["b"]["checkpoints"] = []
	data["destination"]["position"] = [1, 1]
	_assert_rejected(data, "revisits a cell")


func test_rejects_segment_loop() -> void:
	# Segment b ends on a portal leading back to the start of segment a.
	var data := LevelFixtures.portal_corridor()
	data["routes"]["b"]["nodes"] = [[4, 1], [5, 1], [6, 1], [6, 2]]
	data["destination"]["position"] = [0, 2]
	LevelFixtures.add_portal(data, "p_back", Vector2i(6, 2), "p_start")
	LevelFixtures.add_portal(data, "p_start", Vector2i(0, 1))
	_assert_rejected(data, "route segments form a loop at 'a'")


func test_rejects_portal_requiring_unknown_switch() -> void:
	_assert_rejected(LevelFixtures.portal_corridor(["ghost"]), "portal 'p_in' requires unknown switch 'ghost'")
