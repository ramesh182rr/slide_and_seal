extends TestCase
## PuzzleSolver (minimum solutions, honest limits) and the softlock scan.
## Base fixture: 7x3 corridor, route along y = 1, checkpoint "cp" at (3,1), core starts at (0,1).

const PUSH := MechanismIds.PUSH_PULSE


func _level(data: Dictionary) -> LevelDefinition:
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func test_route_only_level_needs_zero_actions() -> void:
	var result := PuzzleSolver.solve(_level(LevelFixtures.corridor()))
	assert_true(result.solvable)
	assert_eq(result.minimum_actions, 0)
	assert_eq(result.solution.size(), 2, "run to checkpoint, run to seal")


func test_finds_minimum_with_free_core_runs() -> void:
	# Two blocks on the route; each needs exactly one push to clear.
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(2, 1))
	LevelFixtures.add_block(data, "b", Vector2i(5, 1))
	LevelFixtures.allow_everywhere(data, [PUSH])
	var result := PuzzleSolver.solve(_level(data))
	assert_true(result.solvable)
	assert_eq(result.minimum_actions, 2)
	var session := PuzzleSession.new(_level(data))
	for action: PuzzleAction in result.solution:
		assert_true(session.apply(action).is_ok(), action.describe())
	assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)


func test_proves_unsolvable_when_search_is_exhausted() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "heavy", Vector2i(5, 1), false)
	var result := PuzzleSolver.solve(_level(data))
	assert_false(result.solvable)
	assert_false(result.limit_hit, "every reachable state was explored, so unsolvable is proven")


func test_reports_limit_instead_of_claiming_unsolvable() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(5, 1))
	LevelFixtures.add_block(data, "spare", Vector2i(2, 0))
	LevelFixtures.allow_everywhere(data, [PUSH])
	var result := PuzzleSolver.solve(_level(data), 3)
	assert_false(result.solvable)
	assert_true(result.limit_hit)


func test_solve_is_deterministic() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(2, 1))
	LevelFixtures.add_block(data, "b", Vector2i(5, 1))
	LevelFixtures.allow_everywhere(data, [PUSH])
	var first := PuzzleSolver.solve(_level(data))
	var second := PuzzleSolver.solve(_level(data))
	var describe := func(result: PuzzleSolver.Result) -> PackedStringArray:
		var steps := PackedStringArray()
		for action: PuzzleAction in result.solution:
			steps.append(action.describe())
		return steps
	assert_eq(describe.call(first), describe.call(second))


func test_scan_finds_shortest_dead_end() -> void:
	# Push is only allowed during setup; running first strands the core behind the block.
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(5, 1))
	data["setup"] = {"allowed_mechanisms": [PUSH]}
	var analysis := PuzzleSolver.analyze(_level(data), 2)
	assert_true(analysis.dead_end_states > 0)
	assert_eq(analysis.unknown_states, 0)
	assert_eq(analysis.dead_end_example.size(), 1)
	assert_eq(analysis.dead_end_example[0].kind, PuzzleAction.Kind.RUN_CORE)


func test_scan_finds_no_dead_ends_in_forgiving_level() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(5, 1))
	LevelFixtures.allow_everywhere(data, [PUSH])
	var analysis := PuzzleSolver.analyze(_level(data), 2)
	assert_eq(analysis.dead_end_states, 0)
	assert_eq(analysis.unknown_states, 0)


func test_scan_reports_unknown_when_closure_limit_is_tiny() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.corridor(), "a", Vector2i(5, 1))
	LevelFixtures.allow_everywhere(data, [PUSH])
	var analysis := PuzzleSolver.analyze(_level(data), 1, 2)
	assert_true(analysis.unknown_states > 0, "states that cannot be decided are reported, not guessed")
