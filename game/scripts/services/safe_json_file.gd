class_name SafeJsonFile
extends RefCounted
## Crash-safe, versioned JSON files for player data (docs/01 §13: "versioned and recoverable").
## Write: temp file first, the previous file kept as `.bak`, then the temp file renamed into place.
## Read: the file, else the backup; an unreadable or unsupported file is renamed `.corrupt`
## (never deleted), so nothing is silently destroyed.


class ReadResult:
	extends RefCounted
	## The loaded data, or empty when nothing readable was found.
	var data: Dictionary = {}
	var found: bool = false
	var notes: PackedStringArray = PackedStringArray()


static func write(path: String, data: Dictionary) -> bool:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  ", true))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(temp_path, path) == OK


## `is_valid(data) -> bool` checks the structure beyond the schema version.
## `label` names the data in notes ("restored <label> from backup").
static func read(path: String, schema_version: int, is_valid: Callable, label: String) -> ReadResult:
	var result := ReadResult.new()
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return result
	if _try(path, schema_version, is_valid, result):
		return result
	if FileAccess.file_exists(path):
		var aside := path + ".corrupt"
		DirAccess.remove_absolute(aside)
		DirAccess.rename_absolute(path, aside)
		result.notes.append("set aside unreadable %s as %s" % [path.get_file(), aside.get_file()])
	if _try(path + ".bak", schema_version, is_valid, result):
		result.notes.append("restored %s from backup" % label)
		return result
	result.notes.append("no readable save; starting fresh")
	return result


static func _try(file_path: String, schema_version: int, is_valid: Callable, result: ReadResult) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		result.notes.append("%s is not valid JSON" % file_path.get_file())
		return false
	var data: Dictionary = json.data
	if int(data.get("schema_version", 0)) != schema_version or not is_valid.call(data):
		result.notes.append("%s has an unsupported format" % file_path.get_file())
		return false
	result.data = data
	result.found = true
	return true
