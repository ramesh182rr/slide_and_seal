class_name LevelCatalog
extends RefCounted
## Ordered list of playable levels grouped by world (res://data/catalog.json).
## Every entry is loaded through LevelLoader, so a broken level never reaches the menu.

const DEFAULT_PATH := "res://data/catalog.json"
const LEVELS_DIR := "res://data/levels"
const SUPPORTED_SCHEMA_VERSION := 1


class Entry:
	extends RefCounted
	var level_id: String = ""
	var path: String = ""
	var title: String = ""
	var world_title: String = ""
	## Position in play order across all worlds, starting at 0.
	var order: int = 0


class World:
	extends RefCounted
	var id: String = ""
	var title: String = ""
	var entries: Array[Entry] = []


var worlds: Array[World] = []
var entries: Array[Entry] = []
var errors: PackedStringArray = PackedStringArray()


static func load_default() -> LevelCatalog:
	return load_file(DEFAULT_PATH)


static func load_file(path: String) -> LevelCatalog:
	var catalog := LevelCatalog.new()
	if not FileAccess.file_exists(path):
		catalog.errors.append("%s: file not found" % path)
		return catalog
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		catalog.errors.append("%s: invalid JSON" % path)
		return catalog
	var data: Dictionary = json.data
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		catalog.errors.append("%s: schema_version must be %d" % [path, SUPPORTED_SCHEMA_VERSION])
		return catalog
	var seen: Dictionary[String, bool] = {}
	for world_data: Variant in data.get("worlds", []):
		if typeof(world_data) != TYPE_DICTIONARY:
			catalog.errors.append("%s: every world must be an object" % path)
			continue
		var world := World.new()
		world.id = str((world_data as Dictionary).get("id", ""))
		world.title = str((world_data as Dictionary).get("title", ""))
		for level_id: Variant in (world_data as Dictionary).get("levels", []):
			var entry := catalog._load_entry(str(level_id), world, seen)
			if entry != null:
				world.entries.append(entry)
		catalog.worlds.append(world)
	return catalog


func entry(level_id: String) -> Entry:
	for candidate: Entry in entries:
		if candidate.level_id == level_id:
			return candidate
	return null


## The entry after `level_id` in play order, or null at the end.
func next_after(level_id: String) -> Entry:
	var current := entry(level_id)
	if current == null or current.order + 1 >= entries.size():
		return null
	return entries[current.order + 1]


func _load_entry(level_id: String, world: World, seen: Dictionary[String, bool]) -> Entry:
	if seen.has(level_id):
		errors.append("level '%s' is listed twice" % level_id)
		return null
	seen[level_id] = true
	var path := LEVELS_DIR.path_join(level_id + ".json")
	var loaded := LevelLoader.load_file(path)
	if not loaded.is_ok():
		errors.append_array(loaded.errors)
		return null
	if loaded.level.id != level_id:
		errors.append("%s declares id '%s'" % [path, loaded.level.id])
		return null
	var result := Entry.new()
	result.level_id = level_id
	result.path = path
	result.title = loaded.level.title
	result.world_title = world.title
	result.order = entries.size()
	entries.append(result)
	return result
