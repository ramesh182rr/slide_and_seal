extends TestCase
## End-to-end progress: locks in level select, saving on completion, stars, new best, persistence.

const APP_SCENE := "res://scenes/app/app_root.tscn"
const PATH := "user://test_progress_flow.json"


func _spawn(clear: bool = true) -> AppRoot:
	if clear:
		TestFiles.remove_progress(PATH)
	var app: AppRoot = (load(APP_SCENE) as PackedScene).instantiate()
	app.instant_playback = true
	app.quit_on_exit = false
	app.settings_path = "user://test_settings_unused.json"
	app.progress_path = PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func after_each() -> void:
	TestFiles.remove_progress(PATH)


func _complete_level_one(app: AppRoot) -> GameplayController:
	app.start_level("world_01_level_001")
	var gameplay := app.current_screen() as GameplayController
	for i: int in 2:
		assert_true(gameplay.request_action(PuzzleAction.run_core()).is_ok(), "level 1: run, then resume")
	return gameplay


func test_fresh_progress_locks_all_but_the_first_level() -> void:
	var app := _spawn()
	app.show_level_select()
	var screen := app.current_screen() as LevelSelectScreen
	assert_false(screen.level_button("world_01_level_001").disabled)
	assert_true(screen.level_button("world_01_level_002").disabled)
	assert_eq(screen.row_texts("world_01_level_002")[1], "Locked")
	assert_true(screen.level_button("world_01_level_003").disabled)
	app.free()
	TestFiles.remove_progress(PATH)


func test_completion_saves_unlocks_next_and_shows_stars() -> void:
	var app := _spawn()
	var gameplay := _complete_level_one(app)
	var card := gameplay.get_hud().completion_card()
	assert_eq(card.stars_shown(), 3, "0 actions matches the proven optimum 0")
	assert_true(card.is_new_best_shown())
	assert_true(app.progress().is_completed("world_01_level_001"))
	assert_true(FileAccess.file_exists(PATH), "progress is written to disk on completion")
	card.levels_button().pressed.emit()
	var screen := app.current_screen() as LevelSelectScreen
	assert_eq(screen.row_texts("world_01_level_001")[1], "Best 0")
	assert_eq(screen.row_stars("world_01_level_001"), 3)
	assert_false(screen.level_button("world_01_level_002").disabled, "completing level 1 opens level 2")
	assert_true(screen.level_button("world_01_level_003").disabled)
	app.free()
	TestFiles.remove_progress(PATH)


func test_progress_survives_a_restart_of_the_app() -> void:
	var first := _spawn()
	_complete_level_one(first)
	first.free()
	var second := _spawn(false)
	assert_true(second.progress().is_completed("world_01_level_001"))
	second.show_level_select()
	assert_false((second.current_screen() as LevelSelectScreen).level_button("world_01_level_002").disabled)
	second.free()
	TestFiles.remove_progress(PATH)


func test_worse_replay_is_not_a_new_best_and_keeps_the_record() -> void:
	# "Lever and Gate": levers A and B are needed; lever C opens a gate off the route (a wasted move).
	var app := _spawn()
	app.start_level("world_01_level_003")
	var gameplay := app.current_screen() as GameplayController
	var optimal: Array[PuzzleAction] = [
		PuzzleAction.run_core(), PuzzleAction.toggle_switch("lever_a"), PuzzleAction.run_core(),
		PuzzleAction.toggle_switch("lever_b"), PuzzleAction.run_core(),
	]
	for action: PuzzleAction in optimal:
		gameplay.request_action(action)
	assert_eq(app.progress().best_actions("world_01_level_003"), 2)
	gameplay.request_restart()
	var wasteful: Array[PuzzleAction] = [
		PuzzleAction.run_core(), PuzzleAction.toggle_switch("lever_a"), PuzzleAction.run_core(),
		PuzzleAction.toggle_switch("lever_c"), PuzzleAction.toggle_switch("lever_b"), PuzzleAction.run_core(),
	]
	for action: PuzzleAction in wasteful:
		var result := gameplay.request_action(action)
		assert_true(result.is_ok(), "%s: %s" % [action.describe(), result.message])
	var card := gameplay.get_hud().completion_card()
	assert_eq(gameplay.get_session().get_state().mechanism_action_count, 3)
	assert_false(card.is_new_best_shown())
	assert_eq(card.stars_shown(), 1, "3 actions is above target 2")
	assert_eq(app.progress().best_actions("world_01_level_003"), 2, "the record is kept")
	app.free()
