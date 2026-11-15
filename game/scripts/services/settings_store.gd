class_name SettingsStore
extends RefCounted
## Player settings (P-019), stored crash-safely through SafeJsonFile.
## Only settings that do something exist; more are added together with their features.

const DEFAULT_PATH := "user://settings.json"
const SCHEMA_VERSION := 1

var path: String
var load_notes: PackedStringArray = PackedStringArray()
## Skip animations: committed results appear instantly (docs/01 §12 accessibility).
var reduced_motion: bool = false


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_from_disk() -> void:
	var result := SafeJsonFile.read(path, SCHEMA_VERSION, func(_data: Dictionary) -> bool: return true, "settings")
	load_notes = result.notes
	reduced_motion = bool(result.data.get("reduced_motion", false))


func save_to_disk() -> bool:
	return SafeJsonFile.write(path, {"schema_version": SCHEMA_VERSION, "reduced_motion": reduced_motion})
