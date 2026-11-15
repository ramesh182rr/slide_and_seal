extends TestCase
## Push Pulse (decision D-007). Base fixture: 7x3 corridor, route along y = 1,
## checkpoint "cp" at (3,1), core starts at (0,1).

const ALL := [MechanismIds.GRAVITY_SHIFT, MechanismIds.PUSH_PULSE]
const UP := Grid.Direction.UP
const RIGHT := Grid.Direction.RIGHT
const DOWN := Grid.Direction.DOWN
const LEFT := Grid.Direction.LEFT


## Corridor with blocks b0, b1, ... at `blocks`; push allowed everywhere.
func _level(blocks: Array[Vector2i], walls: Array = [], with_zone: bool = false) -> LevelDefinition:
	var data := LevelFixtures.corridor()
	for i: int in blocks.size():
		LevelFixtures.add_block(data, "b%d" % i, blocks[i])
	data["terrain"]["walls"] = walls
	if with_zone:
		LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])
		LevelFixtures.allow_everywhere(data, ALL)
	else:
		LevelFixtures.allow_everywhere(data, [MechanismIds.PUSH_PULSE])
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func _push(level: LevelDefinition, object_id: String, direction: Grid.Direction) -> ActionResult:
	return PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.push(object_id, direction))


func test_push_moves_exactly_one_cell() -> void:
	var level := _level([Vector2i(2, 0)])
	var result := _push(level, "b0", RIGHT)
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.object_by_id("b0").position, Vector2i(3, 0))
	assert_eq(result.state.mechanism_action_count, 1)
	assert_eq(result.object_moves.size(), 1)
	assert_eq(result.object_moves[0].cause, ObjectMove.Cause.PUSH)
	assert_eq(result.object_moves[0].from_cell, Vector2i(2, 0))
	assert_eq(result.object_moves[0].to_cell, Vector2i(3, 0))


func test_rejects_push_into_wall() -> void:
	assert_eq(_push(_level([Vector2i(2, 0)], [[3, 0]]), "b0", RIGHT).failure, ActionResult.Failure.MOVE_BLOCKED)


func test_rejects_push_out_of_bounds() -> void:
	assert_eq(_push(_level([Vector2i(2, 0)]), "b0", UP).failure, ActionResult.Failure.MOVE_BLOCKED)


func test_rejects_push_into_core() -> void:
	assert_eq(_push(_level([Vector2i(0, 0)]), "b0", DOWN).failure, ActionResult.Failure.MOVE_BLOCKED)


func test_push_does_not_chain() -> void:
	var level := _level([Vector2i(2, 0), Vector2i(3, 0)])
	var state := level.create_initial_state()
	var key_before := state.to_key()
	var result := PuzzleSimulator.apply_action(level, state, PuzzleAction.push("b0", RIGHT))
	assert_eq(result.failure, ActionResult.Failure.MOVE_BLOCKED)
	assert_eq(state.to_key(), key_before)


func test_rejects_unknown_object() -> void:
	assert_eq(_push(_level([Vector2i(2, 0)]), "ghost", RIGHT).failure, ActionResult.Failure.INVALID_TARGET)


func test_rejects_non_pushable_object() -> void:
	var data := LevelFixtures.corridor()
	LevelFixtures.add_block(data, "heavy", Vector2i(2, 0), false)
	LevelFixtures.add_block(data, "light", Vector2i(4, 0))
	LevelFixtures.allow_everywhere(data, [MechanismIds.PUSH_PULSE])
	var level := LevelFixtures.build(data)
	assert_eq(_push(level, "heavy", RIGHT).failure, ActionResult.Failure.INVALID_TARGET)


func test_rejects_when_mechanism_not_allowed() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "b0", Vector2i(2, 0))
	var level := LevelFixtures.build(data)
	assert_eq(_push(level, "b0", RIGHT).failure, ActionResult.Failure.MECHANISM_NOT_ALLOWED)


func test_rejects_after_completion() -> void:
	var session := PuzzleSession.new(_level([Vector2i(2, 0)]))
	session.apply(PuzzleAction.run_core())
	session.apply(PuzzleAction.run_core())
	assert_eq(session.apply(PuzzleAction.push("b0", RIGHT)).failure, ActionResult.Failure.WRONG_PHASE)


func test_push_clears_blocked_route() -> void:
	var session := PuzzleSession.new(_level([Vector2i(5, 1)]))
	assert_eq(session.apply(PuzzleAction.run_core()).state.phase, PuzzleState.Phase.CHECKPOINT_PAUSED)
	var blocked := session.apply(PuzzleAction.run_core())
	assert_eq(blocked.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(session.apply(PuzzleAction.run_core()).failure, ActionResult.Failure.ROUTE_BLOCKED)
	assert_true(session.apply(PuzzleAction.push("b0", UP)).is_ok())
	assert_eq(session.get_state().phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION, "pushing does not move the core")
	var finished := session.apply(PuzzleAction.run_core())
	assert_true(finished.is_ok(), finished.message)
	assert_eq(finished.state.phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(finished.state.mechanism_action_count, 1)
	assert_eq(finished.state.core_run_count, 3)


func test_push_into_gravity_zone_then_settles() -> void:
	var level := _level([Vector2i(4, 2)], [], true)
	var result := _push(level, "b0", RIGHT)
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.object_by_id("b0").position, Vector2i(5, 0))
	assert_eq(result.object_moves.size(), 2)
	assert_eq(result.object_moves[0].cause, ObjectMove.Cause.PUSH)
	assert_eq(result.object_moves[1].cause, ObjectMove.Cause.GRAVITY)
	assert_eq(result.object_moves[1].from_cell, Vector2i(5, 2))


func test_push_against_gravity_has_no_effect() -> void:
	var level := _level([Vector2i(5, 0)], [], true)
	var state := level.create_initial_state()
	var key_before := state.to_key()
	var result := PuzzleSimulator.apply_action(level, state, PuzzleAction.push("b0", DOWN))
	assert_eq(result.failure, ActionResult.Failure.NO_EFFECT)
	assert_eq(state.to_key(), key_before)


func test_push_out_of_gravity_zone() -> void:
	var level := _level([Vector2i(5, 0)], [], true)
	var result := _push(level, "b0", LEFT)
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.object_by_id("b0").position, Vector2i(4, 0))
	assert_eq(result.object_moves.size(), 1)


func test_preview_matches_apply_and_does_not_mutate() -> void:
	var level := _level([Vector2i(4, 2)], [], true)
	var state := level.create_initial_state()
	var key_before := state.to_key()
	var action := PuzzleAction.push("b0", RIGHT)
	var preview := PuzzleSimulator.preview_action(level, state, action)
	assert_eq(state.to_key(), key_before)
	assert_eq(preview.state.to_key(), PuzzleSimulator.apply_action(level, state, action).state.to_key())


func test_undo_restores_state_after_push() -> void:
	var session := PuzzleSession.new(_level([Vector2i(4, 2)], [], true))
	var before := session.get_state().to_key()
	assert_true(session.apply(PuzzleAction.push("b0", RIGHT)).is_ok())
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), before)
