extends TestCase
## PuzzleSimulator: core travel, checkpoints, blocking and purity (decisions D-003, P-001..P-004).

var _run := PuzzleAction.run_core()


func test_run_from_setup_stops_at_checkpoint() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor())
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run)
	assert_true(result.is_ok(), result.message)
	var state := result.state
	assert_eq(state.phase, PuzzleState.Phase.CHECKPOINT_PAUSED)
	assert_eq(PuzzleSimulator.core_position(level, state), Vector2i(3, 1))
	assert_eq(state.reached_checkpoint_ids, PackedStringArray(["cp"]))
	assert_eq(state.core_run_count, 1)
	assert_eq(result.travel.stop_reason, CoreTravelResult.StopReason.CHECKPOINT)
	assert_eq(result.travel.checkpoint_id, "cp")
	assert_eq(result.travel.path, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)] as Array[Vector2i])


func test_resume_from_checkpoint_completes_level() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor())
	var paused := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run).state
	var result := PuzzleSimulator.apply_action(level, paused, _run)
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(PuzzleSimulator.core_position(level, result.state), level.destination)
	assert_eq(result.state.core_run_count, 2)
	assert_eq(result.travel.stop_reason, CoreTravelResult.StopReason.DESTINATION)
	assert_eq(result.travel.path, [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)] as Array[Vector2i])


func test_run_rejected_after_completion() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor())
	var state := level.create_initial_state()
	state = PuzzleSimulator.apply_action(level, state, _run).state
	state = PuzzleSimulator.apply_action(level, state, _run).state
	var result := PuzzleSimulator.apply_action(level, state, _run)
	assert_false(result.is_ok())
	assert_eq(result.failure, ActionResult.Failure.WRONG_PHASE)
	assert_null(result.state)


func test_non_pausing_checkpoint_is_recorded_but_passed() -> void:
	var data := LevelFixtures.corridor()
	data["routes"]["main"]["checkpoints"][0]["auto_pause"] = false
	var level := LevelFixtures.build(data)
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run)
	assert_eq(result.state.phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(result.state.reached_checkpoint_ids, PackedStringArray(["cp"]))
	assert_eq(result.travel.path.size(), 6)


func test_block_on_route_stops_core_on_last_free_cell() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 1)]))
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run)
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(PuzzleSimulator.core_position(level, result.state), Vector2i(1, 1))
	assert_eq(result.travel.stop_reason, CoreTravelResult.StopReason.BLOCKED)
	assert_eq(result.travel.blocked_cell, Vector2i(2, 1))
	assert_eq(result.travel.path, [Vector2i(1, 1)] as Array[Vector2i])


func test_resume_rejected_while_still_blocked() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 1)]))
	var blocked := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run).state
	var key_before := blocked.to_key()
	var result := PuzzleSimulator.apply_action(level, blocked, _run)
	assert_eq(result.failure, ActionResult.Failure.ROUTE_BLOCKED)
	assert_null(result.state)
	assert_eq(blocked.to_key(), key_before)


func test_run_rejected_when_first_step_is_blocked() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(1, 1)]))
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run)
	assert_eq(result.failure, ActionResult.Failure.ROUTE_BLOCKED)


func test_blocked_core_resumes_once_route_is_clear() -> void:
	# Stands in for a future mechanism action (e.g. push) clearing the lane.
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(2, 1)]))
	var blocked := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run).state
	var cleared := blocked.clone()
	cleared.objects[0].position = Vector2i(2, 0)
	var result := PuzzleSimulator.apply_action(level, cleared, _run)
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.phase, PuzzleState.Phase.CHECKPOINT_PAUSED)
	assert_eq(result.travel.path, [Vector2i(2, 1), Vector2i(3, 1)] as Array[Vector2i])


func test_checkpoint_followed_by_block_pauses_at_checkpoint() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(4, 1)]))
	var first := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run)
	assert_eq(first.state.phase, PuzzleState.Phase.CHECKPOINT_PAUSED)
	assert_eq(PuzzleSimulator.core_position(level, first.state), Vector2i(3, 1))
	var second := PuzzleSimulator.apply_action(level, first.state, _run)
	assert_eq(second.failure, ActionResult.Failure.ROUTE_BLOCKED)


func test_off_route_object_does_not_block() -> void:
	var data := LevelFixtures.corridor_with_blocks([Vector2i(2, 0), Vector2i(4, 2)])
	data["routes"]["main"]["checkpoints"] = []
	var level := LevelFixtures.build(data)
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), _run)
	assert_eq(result.state.phase, PuzzleState.Phase.LEVEL_COMPLETED)


func test_apply_never_mutates_input_state() -> void:
	# Block right after the checkpoint: the first run succeeds, the second is rejected.
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(4, 1)]))
	var state := level.create_initial_state()
	var key_before := state.to_key()
	var success := PuzzleSimulator.apply_action(level, state, _run)
	assert_true(success.is_ok())
	assert_true(success.state != state, "result must be a new state object")
	assert_eq(state.to_key(), key_before, "successful apply must not mutate input")
	var paused := success.state
	var paused_key := paused.to_key()
	var failure := PuzzleSimulator.apply_action(level, paused, _run)
	assert_false(failure.is_ok())
	assert_eq(paused.to_key(), paused_key, "rejected apply must not mutate input")


func test_preview_matches_apply_and_does_not_mutate() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(5, 1)]))
	var state := level.create_initial_state()
	var key_before := state.to_key()
	var preview := PuzzleSimulator.preview_action(level, state, _run)
	assert_eq(state.to_key(), key_before, "preview must not mutate input")
	var applied := PuzzleSimulator.apply_action(level, state, _run)
	assert_eq(preview.state.to_key(), applied.state.to_key())
	assert_eq(preview.travel.path, applied.travel.path)
	assert_eq(preview.travel.stop_reason, applied.travel.stop_reason)


func test_identical_inputs_give_identical_results() -> void:
	var first := _play_sequence()
	var second := _play_sequence()
	assert_eq(first.size(), 3)
	assert_eq(first, second)


## Runs the core until rejected, recording each committed state key.
func _play_sequence() -> PackedStringArray:
	var level := LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(5, 1), Vector2i(2, 0)]))
	var keys := PackedStringArray()
	var state := level.create_initial_state()
	keys.append(state.to_key())
	for i: int in 10:
		var result := PuzzleSimulator.apply_action(level, state, _run)
		if not result.is_ok():
			break
		state = result.state
		keys.append(state.to_key())
	return keys
