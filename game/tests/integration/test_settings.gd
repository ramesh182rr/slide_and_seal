extends TestCase
## Settings (P-019): reduced motion and reset progress, persisted crash-safely.

const APP_SCENE := "res://scenes/app/app_root.tscn"
const PROGRESS := "user://test_settings_progress.json"
const SETTINGS := "user://test_settings.json"


func after_each() -> void:
	TestFiles.remove_progress(PROGRESS)
	TestFiles.remove_progress(SETTINGS)


func _spawn(clear: bool = true) -> AppRoot:
	if clear:
		after_each()
	var app: AppRoot = (load(APP_SCENE) as PackedScene).instantiate()
	app.quit_on_exit = false
	app.progress_path = PROGRESS
	app.settings_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func _settings_screen(app: AppRoot) -> SettingsScreen:
	(app.current_screen() as HomeScreen).settings_requested.emit()
	assert_eq(app.current_screen_name(), AppRoot.SETTINGS)
	return app.current_screen() as SettingsScreen


func test_settings_store_round_trip_and_recovery() -> void:
	after_each()
	var store := SettingsStore.new(SETTINGS)
	store.load_from_disk()
	assert_false(store.reduced_motion, "defaults when no file exists")
	store.reduced_motion = true
	assert_true(store.save_to_disk())
	store.save_to_disk()
	var file := FileAccess.open(SETTINGS, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	var loaded := SettingsStore.new(SETTINGS)
	loaded.load_from_disk()
	assert_true(loaded.reduced_motion, "restored from the backup")
	assert_true(loaded.load_notes.has("restored settings from backup"), str(loaded.load_notes))


func test_home_opens_settings_and_back_returns() -> void:
	var app := _spawn()
	var screen := _settings_screen(app)
	assert_false(screen.reduced_motion_toggle().button_pressed)
	assert_eq(screen.reduced_motion_state_text().strip_edges(), "Off")
	screen.reduced_motion_toggle().button_pressed = true
	assert_eq(screen.reduced_motion_state_text().strip_edges(), "On", "the state is spelled out, not just an icon")
	screen.back_requested.emit()
	assert_eq(app.current_screen_name(), AppRoot.HOME)
	app.free()


func test_reduced_motion_is_saved_and_applied_to_gameplay() -> void:
	var app := _spawn()
	_settings_screen(app).reduced_motion_toggle().button_pressed = true  # Emits `toggled`.
	assert_true(app.settings().reduced_motion)
	app.free()
	var restarted := _spawn(false)
	assert_true(restarted.settings().reduced_motion, "persisted across app restarts")
	restarted.start_level("world_01_level_001")
	assert_true((restarted.current_screen() as GameplayController).instant_playback, "animations are skipped")
	restarted.show_home()
	_settings_screen(restarted).reduced_motion_toggle().button_pressed = false
	restarted.start_level("world_01_level_001")
	assert_false((restarted.current_screen() as GameplayController).instant_playback)
	restarted.free()


func test_vibration_setting_is_saved_and_reaches_gameplay() -> void:
	var app := _spawn()
	assert_true(app.settings().haptics, "on by default")
	_settings_screen(app).haptics_toggle().button_pressed = false  # Emits `toggled`.
	assert_false(app.settings().haptics)
	app.free()
	var restarted := _spawn(false)
	assert_false(restarted.settings().haptics, "persisted across app restarts")
	restarted.start_level("world_01_level_001")
	assert_false((restarted.current_screen() as GameplayController).haptics)
	restarted.free()


func test_reset_progress_asks_first_and_cancel_keeps_progress() -> void:
	var app := _spawn()
	app.progress().record_completion("world_01_level_001", 0)
	app.progress().save_to_disk()
	var screen := _settings_screen(app)
	screen.reset_button().pressed.emit()
	assert_true(screen.reset_dialog().visible, "a confirmation is required")
	screen.reset_dialog().cancel_button().pressed.emit()
	assert_false(screen.reset_dialog().visible)
	assert_true(app.progress().is_completed("world_01_level_001"))
	app.free()


func test_confirmed_reset_erases_and_saves_progress_but_keeps_settings() -> void:
	var app := _spawn()
	app.progress().record_completion("world_01_level_001", 0)
	app.progress().save_to_disk()
	var screen := _settings_screen(app)
	screen.reduced_motion_toggle().button_pressed = true
	screen.reset_button().pressed.emit()
	screen.reset_dialog().confirm_button().pressed.emit()
	assert_false(app.progress().is_completed("world_01_level_001"))
	assert_eq(screen.status_text(), "Progress reset.")
	assert_true(app.settings().reduced_motion, "settings are not part of progress")
	app.free()
	var restarted := _spawn(false)
	assert_false(restarted.progress().is_completed("world_01_level_001"), "the reset was saved")
	restarted.show_level_select()
	assert_true((restarted.current_screen() as LevelSelectScreen).level_button("world_01_level_002").disabled)
	restarted.free()


func test_back_closes_the_reset_dialog_before_leaving_settings() -> void:
	var app := _spawn()
	var screen := _settings_screen(app)
	screen.reset_button().pressed.emit()
	app.handle_back()
	assert_false(screen.reset_dialog().visible)
	assert_eq(app.current_screen_name(), AppRoot.SETTINGS)
	app.handle_back()
	assert_eq(app.current_screen_name(), AppRoot.HOME)
	app.free()
