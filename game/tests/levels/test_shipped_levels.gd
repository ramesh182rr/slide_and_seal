extends TestCase
## Every level in res://data/levels must load cleanly and be completable.
## Until mechanisms and the BFS solver exist (M4), "completable" means running the core
## repeatedly reaches the destination. Levels with mechanisms will need the real solver here.

const LEVELS_DIR := "res://data/levels"


func test_at_least_one_level_ships() -> void:
	assert_true(_level_paths().size() > 0)


func test_every_shipped_level_loads() -> void:
	for path: String in _level_paths():
		var result := LevelLoader.load_file(path)
		assert_eq(result.errors, PackedStringArray(), path)


func test_every_shipped_level_is_completable() -> void:
	for path: String in _level_paths():
		var result := LevelLoader.load_file(path)
		if not result.is_ok():
			continue  # Reported by test_every_shipped_level_loads.
		var session := PuzzleSession.new(result.level)
		var route_length := result.level.routes[result.level.start_route_id].nodes.size()
		for i: int in route_length:
			if not session.apply(PuzzleAction.run_core()).is_ok():
				break
		assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED, path)


static func _level_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(LEVELS_DIR):
		if file_name.ends_with(".json"):
			paths.append(LEVELS_DIR.path_join(file_name))
	paths.sort()
	return paths
