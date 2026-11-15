extends TestCase
## The vertical slice level (decision D-010): intended solution, beat structure and closed skips.

const PATH := "res://data/levels/world_01_slice.json"
const UP := Grid.Direction.UP
const DOWN := Grid.Direction.DOWN
const LEFT := Grid.Direction.LEFT

var _level: LevelDefinition


func _session() -> PuzzleSession:
	if _level == null:
		_level = LevelLoader.load_file(PATH).level
	assert_not_null(_level, "slice level must load")
	return PuzzleSession.new(_level)


func _apply_all(session: PuzzleSession, actions: Array[PuzzleAction]) -> void:
	for action: PuzzleAction in actions:
		var result := session.apply(action)
		assert_true(result.is_ok(), result.message)


func test_intended_solution_completes_in_target_actions() -> void:
	var session := _session()
	_apply_all(session, [
		PuzzleAction.run_core(),
		PuzzleAction.push("block_a", UP),
		PuzzleAction.run_core(),
		PuzzleAction.set_gravity("zone_upper", UP),
		PuzzleAction.run_core(),
		PuzzleAction.push("block_f", LEFT),
		PuzzleAction.set_gravity("zone_lower", UP),
		PuzzleAction.run_core(),
	])
	assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(session.get_state().mechanism_action_count, _level.target_actions)


func test_checkpoints_pause_in_order() -> void:
	var session := _session()
	_apply_all(session, [PuzzleAction.run_core()])
	assert_eq(session.get_state().reached_checkpoint_ids, PackedStringArray(["cp_push"]))
	assert_eq(session.apply(PuzzleAction.run_core()).failure, ActionResult.Failure.ROUTE_BLOCKED,
		"block A must stop the core until pushed")


func test_minimum_is_exactly_four_mechanism_actions() -> void:
	_session()
	var result := PuzzleSolver.solve(_level)
	assert_true(result.solvable)
	assert_false(result.limit_hit)
	assert_eq(result.minimum_actions, 4)


func test_gravity_beat_cannot_be_skipped_by_pushing_b_out() -> void:
	var session := _session()
	_apply_all(session, [PuzzleAction.run_core()])
	assert_eq(session.apply(PuzzleAction.push("block_b", DOWN)).failure, ActionResult.Failure.MOVE_BLOCKED)


func test_full_lower_column_does_not_move_on_gravity_flip() -> void:
	var session := _session()
	_apply_all(session, [
		PuzzleAction.run_core(),
		PuzzleAction.push("block_a", UP),
		PuzzleAction.run_core(),
		PuzzleAction.set_gravity("zone_upper", UP),
		PuzzleAction.run_core(),
	])
	var result := session.apply(PuzzleAction.set_gravity("zone_lower", UP))
	assert_true(result.is_ok())
	assert_eq(result.object_moves.size(), 0, "F and E fill the column: flipping alone moves nothing")
	assert_eq(session.get_state().object_by_id("block_e").position, Vector2i(3, 7))
