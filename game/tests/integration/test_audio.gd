extends TestCase
## Sound (M18): effects, the per-world ambient bed, and the Sound / Music settings.

const APP_SCENE := "res://scenes/app/app_root.tscn"
const PROGRESS := "user://test_progress_audio.json"
const SETTINGS := "user://test_settings_audio.json"


func after_each() -> void:
	TestFiles.remove_progress(PROGRESS)
	TestFiles.remove_progress(SETTINGS)


func _spawn(clear: bool = true) -> AppRoot:
	if clear:
		after_each()
	var app: AppRoot = (load(APP_SCENE) as PackedScene).instantiate()
	app.instant_playback = true
	app.quit_on_exit = false
	app.progress_path = PROGRESS
	app.settings_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func test_every_effect_and_world_loop_exists() -> void:
	for effect: String in AudioDirector.SFX_NAMES:
		assert_true(ResourceLoader.exists("%s/%s.wav" % [AudioDirector.SFX_DIR, effect]), "effect %s" % effect)
	for id: String in WorldTheme.ALL_WORLDS:
		var path := "%s/world_%s.wav" % [AudioDirector.MUSIC_DIR, id.split("_")[1]]
		assert_true(ResourceLoader.exists(path), "ambient loop for %s" % id)
		var stream := load(path) as AudioStreamWAV
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % id)


func test_buttons_moves_and_rejections_make_sound() -> void:
	var app := _spawn()
	var audio := app.audio()
	(app.current_screen().find_child("Play", true, false) as Button).button_down.emit()
	assert_eq(audio.play_count("tap"), 1, "every button ticks")
	app.start_level("world_01_level_003")
	var gameplay := app.current_screen() as GameplayController
	assert_true(gameplay.request_action(PuzzleAction.run_core()).is_ok())
	assert_eq(audio.play_count("run"), 1)
	assert_eq(audio.play_count("checkpoint"), 1, "the run stopped at a checkpoint")
	assert_false(gameplay.request_action(PuzzleAction.push("nothing", Grid.Direction.UP)).is_ok())
	assert_eq(audio.play_count("reject"), 1)
	app.free()
	assert_false(AudioDirector.is_active(), "no director once the app is gone")
	AudioDirector.play("tap")  # Must be a safe no-op.


func test_music_follows_the_world() -> void:
	var app := _spawn()
	var audio := app.audio()
	assert_eq(audio.current_world(), "world_01", "menus use World 1's bed")
	app.show_level_select()
	(app.current_screen() as LevelSelectScreen).show_world(1)
	assert_eq(audio.current_world(), "world_02")
	app.start_level("world_06_quarter_turn")
	assert_eq(audio.current_world(), "world_06")
	app.free()


func test_sound_and_music_settings_are_saved_and_applied() -> void:
	var app := _spawn()
	(app.current_screen() as HomeScreen).settings_requested.emit()
	var screen := app.current_screen() as SettingsScreen
	screen.sound_toggle().button_pressed = false
	screen.music_toggle().button_pressed = false
	assert_false(app.audio().sound_enabled)
	assert_false(app.audio().music_enabled)
	var before := app.audio().play_count("move")
	AudioDirector.play("move")
	assert_eq(app.audio().play_count("move"), before, "silent while sound is off")
	app.free()
	var restarted := _spawn(false)
	assert_false(restarted.settings().sound, "persisted")
	assert_false(restarted.settings().music, "persisted")
	assert_false(restarted.audio().sound_enabled, "applied on start")
	restarted.free()
