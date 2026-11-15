extends TestCase
## Gravity Shift (decision D-006). Base fixture: 7x3 corridor, route along y = 1,
## checkpoint "cp" at (3,1), core starts at (0,1).

const ALL := [MechanismIds.GRAVITY_SHIFT, MechanismIds.PUSH_PULSE]
const UP := Grid.Direction.UP
const DOWN := Grid.Direction.DOWN
const LEFT := Grid.Direction.LEFT


## Column zone "g" at x = 5 (rows 0..2) pointing up, plus the given blocks.
func _column_level(blocks: Array[Vector2i], extra_walls: Array = []) -> LevelDefinition:
	var data := LevelFixtures.corridor()
	for i: int in blocks.size():
		LevelFixtures.add_block(data, "b%d" % i, blocks[i])
	LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])
	data["terrain"]["walls"] = extra_walls
	LevelFixtures.allow_everywhere(data, ALL)
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func test_set_gravity_slides_block_to_zone_edge() -> void:
	var level := _column_level([Vector2i(5, 0)])
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", DOWN))
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.gravity_directions["g"], DOWN)
	assert_eq(result.state.object_by_id("b0").position, Vector2i(5, 2))
	assert_eq(result.state.mechanism_action_count, 1)
	assert_eq(result.object_moves.size(), 1)
	var move := result.object_moves[0]
	assert_eq([move.object_id, move.from_cell, move.to_cell, move.cause, move.core_step],
		["b0", Vector2i(5, 0), Vector2i(5, 2), ObjectMove.Cause.GRAVITY, -1])


func test_stacked_blocks_settle_farthest_first() -> void:
	var level := _column_level([Vector2i(5, 0), Vector2i(5, 1)])
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", DOWN))
	assert_eq(result.state.object_by_id("b1").position, Vector2i(5, 2))
	assert_eq(result.state.object_by_id("b0").position, Vector2i(5, 1))
	assert_eq(result.object_moves.size(), 2)
	assert_eq(result.object_moves[0].object_id, "b1", "the block farthest along gravity resolves first")
	assert_eq(result.object_moves[1].object_id, "b0")


func test_wall_inside_zone_stops_slide() -> void:
	var level := _column_level([Vector2i(5, 0)], [[5, 2]])
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", DOWN))
	assert_eq(result.state.object_by_id("b0").position, Vector2i(5, 1))


func test_core_is_an_obstacle() -> void:
	var level := _column_level([Vector2i(5, 0)])
	var state := level.create_initial_state()
	state.gravity_directions["g"] = DOWN
	GravityResolver.settle(level, state, Vector2i(5, 2))
	assert_eq(state.object_by_id("b0").position, Vector2i(5, 1))


func test_non_gravity_object_is_a_fixed_obstacle() -> void:
	var data := LevelFixtures.corridor()
	LevelFixtures.add_block(data, "a", Vector2i(5, 0))
	LevelFixtures.add_block(data, "fixed", Vector2i(5, 1), true, false)
	LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])
	LevelFixtures.allow_everywhere(data, ALL)
	var level := LevelFixtures.build(data)
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", DOWN))
	assert_true(result.is_ok(), "changing direction succeeds even when nothing moves")
	assert_eq(result.object_moves.size(), 0)
	assert_eq(result.state.object_by_id("a").position, Vector2i(5, 0))
	assert_eq(result.state.object_by_id("fixed").position, Vector2i(5, 1))
	assert_eq(result.state.gravity_directions["g"], DOWN)


func test_objects_outside_zone_are_unaffected() -> void:
	var level := _column_level([Vector2i(5, 0), Vector2i(2, 0)])
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", DOWN))
	assert_eq(result.state.object_by_id("b1").position, Vector2i(2, 0))


func test_rejects_same_direction() -> void:
	var level := _column_level([Vector2i(5, 0)])
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", UP))
	assert_eq(result.failure, ActionResult.Failure.NO_EFFECT)


func test_rejects_direction_not_allowed_by_zone() -> void:
	var level := _column_level([Vector2i(5, 0)])
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", LEFT))
	assert_eq(result.failure, ActionResult.Failure.INVALID_DIRECTION)


func test_rejects_unknown_zone() -> void:
	var level := _column_level([Vector2i(5, 0)])
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("nope", DOWN))
	assert_eq(result.failure, ActionResult.Failure.INVALID_TARGET)


func test_rejects_when_mechanism_not_allowed() -> void:
	var data := LevelFixtures.corridor()
	LevelFixtures.add_block(data, "b", Vector2i(5, 0))
	LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])
	var level := LevelFixtures.build(data)
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("g", DOWN))
	assert_eq(result.failure, ActionResult.Failure.MECHANISM_NOT_ALLOWED)


func test_rejects_after_completion() -> void:
	var level := _column_level([Vector2i(5, 0)])
	var session := PuzzleSession.new(level)
	session.apply(PuzzleAction.run_core())
	session.apply(PuzzleAction.run_core())
	assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(session.apply(PuzzleAction.set_gravity("g", DOWN)).failure, ActionResult.Failure.WRONG_PHASE)


func test_vacated_core_cell_lets_block_fall_during_travel() -> void:
	# Column zone at x = 0 pointing down: the block rests on the core at (0,1) until it leaves.
	var data := LevelFixtures.corridor()
	LevelFixtures.add_block(data, "b", Vector2i(0, 0))
	LevelFixtures.add_gravity_zone(data, "g", Vector2i(0, 0), Vector2i(1, 3), "down", ["down"])
	var level := LevelFixtures.build(data)
	assert_not_null(level, str(LevelLoader.from_dict(data).errors))
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.run_core())
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.object_by_id("b").position, Vector2i(0, 2))
	assert_eq(result.object_moves.size(), 1)
	assert_eq(result.object_moves[0].core_step, 0, "the block falls right after the core's first step")


func test_every_committed_state_is_settled() -> void:
	var level := _column_level([Vector2i(5, 0), Vector2i(4, 2)])
	var session := PuzzleSession.new(level)
	var actions: Array[PuzzleAction] = [
		PuzzleAction.push("b1", Grid.Direction.RIGHT),
		PuzzleAction.set_gravity("g", DOWN),
		PuzzleAction.set_gravity("g", UP),
		PuzzleAction.run_core(),
		PuzzleAction.set_gravity("g", DOWN),
	]
	for action: PuzzleAction in actions:
		var result := session.apply(action)
		assert_true(result.is_ok(), result.message)
		var probe := session.get_state().clone()
		var core_cell := PuzzleSimulator.core_position(level, probe)
		assert_eq(GravityResolver.settle(level, probe, core_cell).size(), 0, "state after %d must be settled" % action.kind)


func test_preview_matches_apply() -> void:
	var level := _column_level([Vector2i(5, 0), Vector2i(5, 1)])
	var state := level.create_initial_state()
	var key_before := state.to_key()
	var action := PuzzleAction.set_gravity("g", DOWN)
	var preview := PuzzleSimulator.preview_action(level, state, action)
	assert_eq(state.to_key(), key_before)
	var applied := PuzzleSimulator.apply_action(level, state, action)
	assert_eq(preview.state.to_key(), applied.state.to_key())
	assert_eq(preview.object_moves.size(), applied.object_moves.size())
