class_name AppRoot
extends Node
## Top-level navigation: Home → Level select → Gameplay, and Home → Settings (P-012, P-019).
## Owns exactly one screen at a time. Android Back / Escape: gameplay handles its own (P-009);
## level select and settings → home; home → exit.

signal exit_requested

const GAMEPLAY_SCENE := preload("res://scenes/gameplay/gameplay_root.tscn")
const HOME := "home"
const LEVEL_SELECT := "level_select"
const GAMEPLAY := "gameplay"
const SETTINGS := "settings"

## Passed to gameplay (reduced motion; tests).
@export var instant_playback: bool = false
## Quit the app on Back from home. Tests turn this off and listen to `exit_requested`.
@export var quit_on_exit: bool = true
## Where progress is saved. Tests point this at a scratch file.
@export var progress_path: String = ProgressStore.DEFAULT_PATH
## Startup brand reveal over Home (skipped when instant_playback is on, e.g. in tests).
@export var show_splash: bool = true
## Where settings are saved. Tests point this at a scratch file.
@export var settings_path: String = SettingsStore.DEFAULT_PATH

var _catalog: LevelCatalog
var _progress: ProgressStore
var _settings: SettingsStore
var _screen: Node
var _screen_name := ""
var _current_level_id := ""
## One live diorama shared by Home and Campaign: its boards are built once (during the startup
## warm-up) and survive screen changes, so paging through worlds never rebuilds anything.
var _diorama: DioramaView
var _audio: AudioDirector


func _ready() -> void:
	_audio = AudioDirector.new()
	_audio.name = "Audio"
	add_child(_audio)
	_diorama = DioramaView.new()
	_diorama.name = "SharedDiorama"
	_catalog = LevelCatalog.load_default()
	for message: String in _catalog.errors:
		push_error("Level catalog: " + message)
	_progress = ProgressStore.new(progress_path)
	_progress.load_from_disk()
	for note: String in _progress.load_notes:
		push_warning("Progress: " + note)
	_settings = SettingsStore.new(settings_path)
	_settings.load_from_disk()
	for note: String in _settings.load_notes:
		push_warning("Settings: " + note)
	_audio.sound_enabled = _settings.sound
	_audio.music_enabled = _settings.music
	# Development: `godot --path game -- --level=world_05_reflector_logic` jumps straight into a level.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level=") and _catalog.entry(arg.trim_prefix("--level=")) != null:
			start_level(arg.trim_prefix("--level="))
			return
	show_home()
	if show_splash and not instant_playback:
		var warmup := ShaderWarmup.new()
		warmup.name = "ShaderWarmup"
		var paths := PackedStringArray()
		for world: LevelCatalog.World in _catalog.worlds:
			if not world.entries.is_empty():
				paths.append(world.entries.back().path)
		for id: String in WorldTheme.ALL_WORLDS:
			if WorldTheme.showcase_path(id) != "":
				paths.append(WorldTheme.showcase_path(id))
		warmup.setup(paths, _diorama)
		add_child(warmup)
		var splash := SplashOverlay.new()
		splash.name = "Splash"
		splash.reduced_motion = _settings.reduced_motion
		splash.wait_for(warmup)
		add_child(splash)


func catalog() -> LevelCatalog:
	return _catalog


func progress() -> ProgressStore:
	return _progress


func settings() -> SettingsStore:
	return _settings


func current_screen_name() -> String:
	return _screen_name


func current_screen() -> Node:
	return _screen


func current_level_id() -> String:
	return _current_level_id


func show_home() -> void:
	var home := HomeScreen.new()
	var next := next_level_to_play()
	home.setup("Continue  ·  %d. %s" % [next.order + 1, next.title] if next != null else "Continue", _diorama)
	home.play_requested.connect(show_level_select)
	home.continue_requested.connect(continue_campaign)
	home.settings_requested.connect(show_settings)
	_set_screen(home, HOME)


func show_level_select() -> void:
	var screen := LevelSelectScreen.new()
	screen.setup(_catalog, _progress, _diorama)
	screen.level_chosen.connect(start_level)
	screen.back_requested.connect(show_home)
	_set_screen(screen, LEVEL_SELECT)


func show_settings() -> void:
	var screen := SettingsScreen.new()
	screen.setup(_settings.reduced_motion, _settings.haptics, _settings.sound, _settings.music)
	screen.sound_changed.connect(_on_sound_changed)
	screen.music_changed.connect(_on_music_changed)
	screen.haptics_changed.connect(_on_haptics_changed)
	screen.back_requested.connect(show_home)
	screen.reduced_motion_changed.connect(_on_reduced_motion_changed)
	screen.reset_progress_confirmed.connect(_on_reset_progress)
	_set_screen(screen, SETTINGS)


func start_level(level_id: String) -> void:
	var entry := _catalog.entry(level_id)
	if entry == null:
		push_error("Unknown level '%s'" % level_id)
		return
	var gameplay: GameplayController = GAMEPLAY_SCENE.instantiate()
	gameplay.level_path = entry.path
	gameplay.instant_playback = instant_playback or _settings.reduced_motion
	gameplay.haptics = _settings.haptics
	gameplay.quit_on_leave = false
	gameplay.next_level_available = _catalog.next_after(level_id) != null
	gameplay.previous_best_actions = _progress.best_actions(level_id)
	gameplay.level_completed.connect(_on_level_completed.bind(gameplay, level_id))
	gameplay.leave_requested.connect(show_level_select)
	gameplay.level_select_requested.connect(show_level_select)
	gameplay.next_level_requested.connect(_start_next_level)
	_current_level_id = level_id
	_set_screen(gameplay, GAMEPLAY)


## The first unlocked level not yet completed, or null when everything unlocked is sealed.
func next_level_to_play() -> LevelCatalog.Entry:
	for entry: LevelCatalog.Entry in _catalog.entries:
		if _progress.best_actions(entry.level_id) < 0 and Progression.is_unlocked(_catalog, _progress, entry.level_id):
			return entry
	return null


## Home → Continue: straight into the next level to play, or the campaign screen if none is left.
func continue_campaign() -> void:
	var next := next_level_to_play()
	if next == null:
		show_level_select()
	else:
		start_level(next.level_id)


func handle_back() -> void:
	match _screen_name:
		LEVEL_SELECT:
			show_home()
		SETTINGS:
			if not (_screen as SettingsScreen).handle_back():
				show_home()
		HOME:
			exit_requested.emit()
			if quit_on_exit:
				get_tree().quit()
		# GAMEPLAY: the gameplay controller handles Back itself.


func shared_diorama() -> DioramaView:
	return _diorama


func _exit_tree() -> void:
	# Not in the tree while gameplay is on screen: free it with the app.
	if _diorama != null and _diorama.get_parent() == null:
		_diorama.free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if _screen_name != GAMEPLAY and event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()


func _on_level_completed(actions: int, gameplay: GameplayController, level_id: String) -> void:
	_progress.record_completion(level_id, actions)
	if not _progress.save_to_disk():
		push_error("Progress could not be saved to %s" % _progress.path)
	gameplay.previous_best_actions = _progress.best_actions(level_id)


func _on_reduced_motion_changed(enabled: bool) -> void:
	_settings.reduced_motion = enabled
	if not _settings.save_to_disk():
		push_error("Settings could not be saved to %s" % _settings.path)


func _on_sound_changed(enabled: bool) -> void:
	_settings.sound = enabled
	_audio.sound_enabled = enabled
	if not _settings.save_to_disk():
		push_error("Settings could not be saved to %s" % _settings.path)


func _on_music_changed(enabled: bool) -> void:
	_settings.music = enabled
	_audio.music_enabled = enabled
	if not _settings.save_to_disk():
		push_error("Settings could not be saved to %s" % _settings.path)


func audio() -> AudioDirector:
	return _audio


func _on_haptics_changed(enabled: bool) -> void:
	_settings.haptics = enabled
	if not _settings.save_to_disk():
		push_error("Settings could not be saved to %s" % _settings.path)


func _on_reset_progress() -> void:
	_progress.reset()
	if not _progress.save_to_disk():
		push_error("Progress could not be saved to %s" % _progress.path)


func _start_next_level() -> void:
	var next := _catalog.next_after(_current_level_id)
	if next != null:
		start_level(next.level_id)


## Swaps screens. Navigation is often triggered from a signal emitted inside the old screen,
## so the old screen is removed from the tree now and deleted at the end of the frame.
func _set_screen(screen: Node, screen_name: String) -> void:
	_diorama.release()  # Kept alive across screens (see _diorama).
	if _screen != null:
		AudioDirector.play("whoosh")
	if screen_name == HOME or screen_name == SETTINGS:
		AudioDirector.set_world("world_01_awakening")
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	_screen_name = screen_name
	if screen_name != GAMEPLAY:
		_current_level_id = ""
	add_child(screen)
