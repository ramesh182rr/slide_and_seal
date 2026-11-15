extends TestCase
## Every level in res://data/levels must load cleanly, be solvable, and have scoring that matches
## the solver's proven minimum. (The slower softlock scan runs in tools/validate_levels.sh.)

const LEVELS_DIR := "res://data/levels"


func test_at_least_one_level_ships() -> void:
	assert_true(_level_paths().size() > 0)


func test_every_shipped_level_loads() -> void:
	for path: String in _level_paths():
		var result := LevelLoader.load_file(path)
		assert_eq(result.errors, PackedStringArray(), path)


func test_every_shipped_level_is_solvable_with_consistent_scoring() -> void:
	for path: String in _level_paths():
		var loaded := LevelLoader.load_file(path)
		if not loaded.is_ok():
			continue  # Reported by test_every_shipped_level_loads.
		var level := loaded.level
		var result := PuzzleSolver.solve(level)
		assert_true(result.solvable, "%s has no solution" % path)
		if not result.solvable:
			continue
		assert_true(level.target_actions >= result.minimum_actions,
			"%s: target %d is below the proven minimum %d" % [path, level.target_actions, result.minimum_actions])
		assert_eq(level.optimal_actions, result.minimum_actions, "%s: optimal_actions must equal the proven minimum" % path)
		# The solver's solution must hold under committed gameplay too.
		var session := PuzzleSession.new(level)
		for action: PuzzleAction in result.solution:
			assert_true(session.apply(action).is_ok(), "%s: %s" % [path, action.describe()])
		assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED, path)


static func _level_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(LEVELS_DIR):
		if file_name.ends_with(".json"):
			paths.append(LEVELS_DIR.path_join(file_name))
	paths.sort()
	return paths
