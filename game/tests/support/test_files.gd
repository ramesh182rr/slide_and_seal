class_name TestFiles
extends RefCounted
## Helpers for tests that touch user:// files. Tests must only ever use scratch paths.


## Deletes a progress file and its .bak / .tmp / .corrupt companions.
static func remove_progress(path: String) -> void:
	assert(not path.ends_with("/progress.json"), "tests must not use the real save file")
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
