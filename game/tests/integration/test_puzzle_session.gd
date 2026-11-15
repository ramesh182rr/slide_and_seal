extends TestCase
## PuzzleSession: commit, undo and restart behaviour (decision P-005).

var _run := PuzzleAction.run_core()


func test_undo_restores_previous_state_exactly() -> void:
	var session := PuzzleSession.new(LevelFixtures.build(LevelFixtures.corridor()))
	var before := session.get_state().to_key()
	assert_true(session.apply(_run).is_ok())
	assert_ne(session.get_state().to_key(), before)
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), before)


func test_undo_without_history_returns_false() -> void:
	var session := PuzzleSession.new(LevelFixtures.build(LevelFixtures.corridor()))
	assert_false(session.can_undo())
	assert_false(session.undo())


func test_rejected_action_changes_nothing() -> void:
	var session := PuzzleSession.new(LevelFixtures.build(LevelFixtures.corridor_with_blocks([Vector2i(1, 1)])))
	var before := session.get_state().to_key()
	var result := session.apply(_run)
	assert_eq(result.failure, ActionResult.Failure.ROUTE_BLOCKED)
	assert_eq(session.get_state().to_key(), before)
	assert_false(session.can_undo(), "rejected actions must not create history")


func test_session_preview_does_not_commit() -> void:
	var session := PuzzleSession.new(LevelFixtures.build(LevelFixtures.corridor()))
	var before := session.get_state().to_key()
	var preview := session.preview(_run)
	assert_true(preview.is_ok())
	assert_eq(session.get_state().to_key(), before)
	assert_false(session.can_undo())
	assert_eq(session.apply(_run).state.to_key(), preview.state.to_key())


func test_restart_restores_initial_state_and_is_undoable() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor())
	var session := PuzzleSession.new(level)
	var initial := level.create_initial_state().to_key()
	session.apply(_run)
	var paused := session.get_state().to_key()
	assert_true(session.restart())
	assert_eq(session.get_state().to_key(), initial)
	assert_true(session.undo(), "restart must be undoable")
	assert_eq(session.get_state().to_key(), paused)


func test_restart_at_initial_state_is_a_no_op() -> void:
	var session := PuzzleSession.new(LevelFixtures.build(LevelFixtures.corridor()))
	assert_false(session.restart())
	assert_false(session.can_undo())


func test_full_playthrough_then_undo_to_start() -> void:
	var level := LevelFixtures.build(LevelFixtures.corridor())
	var session := PuzzleSession.new(level)
	var keys := PackedStringArray([session.get_state().to_key()])
	assert_true(session.apply(_run).is_ok())
	keys.append(session.get_state().to_key())
	assert_true(session.apply(_run).is_ok())
	assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), keys[1])
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), keys[0])
	assert_false(session.can_undo())
