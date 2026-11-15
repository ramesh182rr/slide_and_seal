class_name ProgressStore
extends RefCounted
## Persistent player progress, stored crash-safely through SafeJsonFile (P-013).

const DEFAULT_PATH := "user://progress.json"
const SCHEMA_VERSION := 1


class LevelProgress:
	extends RefCounted
	var completed: bool = false
	## Fewest mechanism actions in any completion, or -1.
	var best_actions: int = -1


var path: String
## Messages about recovery during the last load (for logging and tests).
var load_notes: PackedStringArray = PackedStringArray()
var _levels: Dictionary[String, LevelProgress] = {}


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func is_completed(level_id: String) -> bool:
	return _levels.has(level_id) and _levels[level_id].completed


func best_actions(level_id: String) -> int:
	return _levels[level_id].best_actions if _levels.has(level_id) else -1


## Records a completion. Returns true when it is the first completion or a new best.
func record_completion(level_id: String, actions: int) -> bool:
	var progress: LevelProgress = _levels.get(level_id, LevelProgress.new())
	var improved := not progress.completed or actions < progress.best_actions
	progress.completed = true
	if progress.best_actions == -1 or actions < progress.best_actions:
		progress.best_actions = actions
	_levels[level_id] = progress
	return improved


func load_from_disk() -> void:
	_levels.clear()
	var result := SafeJsonFile.read(path, SCHEMA_VERSION,
		func(data: Dictionary) -> bool: return typeof(data.get("levels")) == TYPE_DICTIONARY, "progress")
	load_notes = result.notes
	if not result.found:
		return
	var levels: Dictionary = result.data["levels"]
	for level_id: Variant in levels.keys():
		var entry: Variant = levels[level_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var progress := LevelProgress.new()
		progress.completed = bool((entry as Dictionary).get("completed", false))
		progress.best_actions = int((entry as Dictionary).get("best_actions", -1))
		_levels[str(level_id)] = progress


## Returns false if the file could not be written.
func save_to_disk() -> bool:
	var data := {"schema_version": SCHEMA_VERSION, "levels": {}}
	for level_id: String in _levels.keys():
		var progress := _levels[level_id]
		data["levels"][level_id] = {"completed": progress.completed, "best_actions": progress.best_actions}
	return SafeJsonFile.write(path, data)


## Forgets every level's progress (the caller saves).
func reset() -> void:
	_levels.clear()
