class_name TestFiles
extends RefCounted
## Helpers for tests that touch user:// files. Tests must only ever use scratch paths.


## Deletes a player-data file and its .bak / .tmp / .corrupt companions. Refuses the real files.
static func remove_progress(path: String) -> void:
	assert(not path.ends_with("/progress.json") and not path.ends_with("/settings.json"),
		"tests must not use the real player-data files")
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
