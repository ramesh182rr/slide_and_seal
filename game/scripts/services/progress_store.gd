class_name ProgressStore
extends RefCounted
## Persistent player progress (docs/01 §13: "save data is versioned and recoverable").
## File: JSON with schema_version. Writes go to a temp file first, the previous save is kept as
## `.bak`, then the temp file replaces the save, so a crash mid-write never loses progress.
## Loading falls back to the backup, then to empty progress; unreadable files are set aside
## (renamed `.corrupt`) rather than overwritten, so nothing is silently destroyed.

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
	load_notes.clear()
	_levels.clear()
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return
	if _try_load(path):
		return
	if FileAccess.file_exists(path):
		_set_aside(path)
	if _try_load(path + ".bak"):
		load_notes.append("restored progress from backup")
		return
	load_notes.append("no readable save; starting fresh")
	_levels.clear()


## Returns false if the file could not be written.
func save_to_disk() -> bool:
	var data := {"schema_version": SCHEMA_VERSION, "levels": {}}
	var ids: Array = _levels.keys()
	ids.sort()
	for level_id: String in ids:
		var progress := _levels[level_id]
		data["levels"][level_id] = {"completed": progress.completed, "best_actions": progress.best_actions}
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(temp_path, path) == OK


func _try_load(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		load_notes.append("%s is not valid JSON" % file_path.get_file())
		return false
	var data: Dictionary = json.data
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION or typeof(data.get("levels")) != TYPE_DICTIONARY:
		load_notes.append("%s has an unsupported format" % file_path.get_file())
		return false
	var loaded: Dictionary[String, LevelProgress] = {}
	var levels: Dictionary = data["levels"]
	for level_id: Variant in levels.keys():
		var entry: Variant = levels[level_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var progress := LevelProgress.new()
		progress.completed = bool((entry as Dictionary).get("completed", false))
		progress.best_actions = int((entry as Dictionary).get("best_actions", -1))
		loaded[str(level_id)] = progress
	_levels = loaded
	return true


func _set_aside(file_path: String) -> void:
	var aside := file_path + ".corrupt"
	DirAccess.remove_absolute(aside)
	DirAccess.rename_absolute(file_path, aside)
	load_notes.append("set aside unreadable %s as %s" % [file_path.get_file(), aside.get_file()])
