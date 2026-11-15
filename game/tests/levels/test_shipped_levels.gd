extends TestCase
## Every level in res://data/levels must load cleanly, be solvable, and have an achievable
## designer target. Uses the test-only exhaustive search (TestSolver) until the M4 solver exists.

const LEVELS_DIR := "res://data/levels"


func test_at_least_one_level_ships() -> void:
	assert_true(_level_paths().size() > 0)


func test_every_shipped_level_loads() -> void:
	for path: String in _level_paths():
		var result := LevelLoader.load_file(path)
		assert_eq(result.errors, PackedStringArray(), path)


func test_every_shipped_level_is_solvable_within_target() -> void:
	for path: String in _level_paths():
		var result := LevelLoader.load_file(path)
		if not result.is_ok():
			continue  # Reported by test_every_shipped_level_loads.
		var solution := TestSolver.solve(result.level)
		assert_not_null(solution, "%s has no solution" % path)
		if solution == null:
			continue
		assert_true(solution.mechanism_actions <= result.level.target_actions,
			"%s: minimum %d mechanism actions exceeds target %d" % [path, solution.mechanism_actions, result.level.target_actions])
		# Replay through a session: the found solution must hold under committed gameplay too.
		var session := PuzzleSession.new(result.level)
		for action: PuzzleAction in solution.actions:
			assert_true(session.apply(action).is_ok(), path)
		assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED, path)


static func _level_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(LEVELS_DIR):
		if file_name.ends_with(".json"):
			paths.append(LEVELS_DIR.path_join(file_name))
	paths.sort()
	return paths
