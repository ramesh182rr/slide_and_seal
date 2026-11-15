extends TestCase
## ProgressStore: recording, persistence, and recovery from damaged files.

const PATH := "user://test_progress_store.json"


func after_each() -> void:
	TestFiles.remove_progress(PATH)


func _fresh() -> ProgressStore:
	TestFiles.remove_progress(PATH)
	return ProgressStore.new(PATH)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_record_completion_keeps_the_best() -> void:
	var store := _fresh()
	assert_false(store.is_completed("a"))
	assert_eq(store.best_actions("a"), -1)
	assert_true(store.record_completion("a", 5), "first completion counts as improved")
	assert_true(store.record_completion("a", 3), "fewer actions is a new best")
	assert_false(store.record_completion("a", 4), "more actions is not")
	assert_true(store.is_completed("a"))
	assert_eq(store.best_actions("a"), 3)
	TestFiles.remove_progress(PATH)


func test_save_and_load_round_trip() -> void:
	var store := _fresh()
	store.record_completion("a", 3)
	store.record_completion("b", 0)
	assert_true(store.save_to_disk())
	var loaded := ProgressStore.new(PATH)
	loaded.load_from_disk()
	assert_eq(loaded.load_notes, PackedStringArray())
	assert_true(loaded.is_completed("a"))
	assert_eq(loaded.best_actions("a"), 3)
	assert_eq(loaded.best_actions("b"), 0)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "the temp file is renamed into place")
	TestFiles.remove_progress(PATH)


func test_missing_file_means_empty_progress() -> void:
	var store := _fresh()
	store.load_from_disk()
	assert_eq(store.load_notes, PackedStringArray())
	assert_false(store.is_completed("a"))


func test_second_save_keeps_previous_as_backup() -> void:
	var store := _fresh()
	store.record_completion("a", 5)
	store.save_to_disk()
	store.record_completion("b", 1)
	store.save_to_disk()
	var backup := ProgressStore.new(PATH + ".bak")
	backup.load_from_disk()
	assert_true(backup.is_completed("a"))
	assert_false(backup.is_completed("b"), "the backup is the previous save")
	TestFiles.remove_progress(PATH)


func test_corrupt_save_recovers_from_backup_and_is_set_aside() -> void:
	var store := _fresh()
	store.record_completion("a", 5)
	store.save_to_disk()
	store.save_to_disk()  # Now progress.json and .bak both hold "a".
	_write(PATH, "{ this is not json")
	var loaded := ProgressStore.new(PATH)
	loaded.load_from_disk()
	assert_true(loaded.is_completed("a"), "progress restored from the backup")
	assert_true(FileAccess.file_exists(PATH + ".corrupt"), "the unreadable file is kept, not destroyed")
	assert_true(loaded.load_notes.has("restored progress from backup"), str(loaded.load_notes))
	TestFiles.remove_progress(PATH)


func test_unreadable_save_without_backup_starts_fresh() -> void:
	_fresh()
	_write(PATH, "[1, 2, 3]")
	var loaded := ProgressStore.new(PATH)
	loaded.load_from_disk()
	assert_false(loaded.is_completed("a"))
	assert_true(loaded.load_notes.has("no readable save; starting fresh"), str(loaded.load_notes))
	assert_true(FileAccess.file_exists(PATH + ".corrupt"))
	TestFiles.remove_progress(PATH)


func test_unsupported_schema_is_not_trusted() -> void:
	_fresh()
	_write(PATH, '{"schema_version": 99, "levels": {"a": {"completed": true, "best_actions": 1}}}')
	var loaded := ProgressStore.new(PATH)
	loaded.load_from_disk()
	assert_false(loaded.is_completed("a"))
	TestFiles.remove_progress(PATH)
