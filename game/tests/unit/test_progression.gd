extends TestCase
## Progression rules (P-013): sequential unlocking and stars.

const PATH := "user://test_progression.json"


func after_each() -> void:
	TestFiles.remove_progress(PATH)


func test_first_level_open_and_each_completion_opens_the_next() -> void:
	TestFiles.remove_progress(PATH)
	var catalog := LevelCatalog.load_default()
	var store := ProgressStore.new(PATH)
	var ids: Array[String] = []
	for entry: LevelCatalog.Entry in catalog.entries:
		ids.append(entry.level_id)
	assert_true(Progression.is_unlocked(catalog, store, ids[0]))
	assert_false(Progression.is_unlocked(catalog, store, ids[1]))
	assert_false(Progression.is_unlocked(catalog, store, ids[2]))
	store.record_completion(ids[0], 0)
	assert_true(Progression.is_unlocked(catalog, store, ids[1]))
	assert_false(Progression.is_unlocked(catalog, store, ids[2]), "only the next level opens")
	assert_false(Progression.is_unlocked(catalog, store, "not_a_level"))


func test_stars() -> void:
	assert_eq(Progression.stars(-1, 4, 4), 0, "not completed")
	assert_eq(Progression.stars(9, 6, 4), 1, "completed above target")
	assert_eq(Progression.stars(6, 6, 4), 2, "target met")
	assert_eq(Progression.stars(4, 6, 4), 3, "proven optimum matched")
	assert_eq(Progression.stars(4, 6, -1), 2, "no proven optimum: never three stars")
	assert_eq(Progression.stars(0, 0, 0), 3)


## D-037 (temporary): with the review switch on, every level is open; off, the normal rule applies.
func test_unlock_all_switch_opens_every_level() -> void:
	var catalog := LevelCatalog.load_default()
	var progress := ProgressStore.new("user://test_progress_unlock_all.json")
	var last: String = catalog.entries[catalog.entries.size() - 1].level_id
	assert_false(Progression.is_unlocked(catalog, progress, last), "locked under the normal rule")
	Progression.unlock_all = true
	assert_true(Progression.is_unlocked(catalog, progress, last), "open while the review switch is on")
	Progression.unlock_all = false
