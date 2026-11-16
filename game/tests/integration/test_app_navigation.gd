extends TestCase
## Menu skeleton (P-012): catalog integrity, Home → Level select → Gameplay, completion card, Back.

const APP_SCENE := "res://scenes/app/app_root.tscn"
## Tests never touch the player's real save.
const TEST_PROGRESS := "user://test_progress_navigation.json"

var _exits := 0


func _spawn() -> AppRoot:
	var app: AppRoot = (load(APP_SCENE) as PackedScene).instantiate()
	app.instant_playback = true
	app.quit_on_exit = false
	app.settings_path = "user://test_settings_unused.json"
	TestFiles.remove_progress(TEST_PROGRESS)
	app.progress_path = TEST_PROGRESS
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_exits = 0
	app.exit_requested.connect(func() -> void: _exits += 1)
	return app


func after_each() -> void:
	TestFiles.remove_progress(TEST_PROGRESS)


func _gameplay(app: AppRoot) -> GameplayController:
	return app.current_screen() as GameplayController


func _solve(gameplay: GameplayController, actions: Array[PuzzleAction]) -> void:
	for action: PuzzleAction in actions:
		assert_true(gameplay.request_action(action).is_ok(), action.describe())


# --- Catalog ------------------------------------------------------------------

func _catalog_ids(catalog: LevelCatalog) -> PackedStringArray:
	var ids := PackedStringArray()
	for entry: LevelCatalog.Entry in catalog.entries:
		ids.append(entry.level_id)
	return ids


## Order-independent of how many levels exist: checks structure, not a hard-coded list.
func test_catalog_loads_in_order_without_errors() -> void:
	var catalog := LevelCatalog.load_default()
	assert_eq(catalog.errors, PackedStringArray())
	var ids := _catalog_ids(catalog)
	assert_true(ids.size() >= 2)
	assert_eq(ids[0], "world_01_level_001", "campaign starts with The First Signal")
	assert_eq(catalog.worlds[0].title, "The Awakening")
	for i: int in ids.size() - 1:
		assert_eq(catalog.next_after(ids[i]).level_id, ids[i + 1])
		assert_eq(catalog.entry(ids[i]).order, i)
	assert_null(catalog.next_after(ids[ids.size() - 1]))


func test_every_level_file_is_in_the_catalog() -> void:
	var catalog := LevelCatalog.load_default()
	for file_name: String in DirAccess.get_files_at(LevelCatalog.LEVELS_DIR):
		if file_name.ends_with(".json"):
			assert_not_null(catalog.entry(file_name.get_basename()), "%s is missing from catalog.json" % file_name)


# --- Navigation -----------------------------------------------------------------

func test_starts_at_home_and_play_opens_level_select() -> void:
	var app := _spawn()
	assert_eq(app.current_screen_name(), AppRoot.HOME)
	(app.current_screen() as HomeScreen).play_requested.emit()
	assert_eq(app.current_screen_name(), AppRoot.LEVEL_SELECT)
	var screen := app.current_screen() as LevelSelectScreen
	assert_eq(screen.listed_level_ids(), _catalog_ids(app.catalog()), "level select lists the catalog, in order")
	assert_eq(screen.row_texts("world_01_level_002")[0], "2.  Dormant Path")
	app.free()


func test_startup_reveal_covers_home_and_a_tap_skips_it() -> void:
	var app: AppRoot = (load(APP_SCENE) as PackedScene).instantiate()
	app.quit_on_exit = false
	app.settings_path = "user://test_settings_unused.json"
	TestFiles.remove_progress(TEST_PROGRESS)
	app.progress_path = TEST_PROGRESS
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	var splash := app.get_node_or_null("Splash") as SplashOverlay
	assert_not_null(splash, "the brand reveal plays on a normal start")
	assert_eq(app.current_screen_name(), AppRoot.HOME, "Home is already underneath")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	splash._on_input(tap)
	assert_true(splash.is_finished(), "a tap skips the reveal")
	app.free()
	var quiet := _spawn()
	assert_null(quiet.get_node_or_null("Splash"), "no reveal with instant playback (tests)")
	quiet.free()


func test_continue_opens_the_next_level_to_play() -> void:
	var app := _spawn()
	assert_eq(app.next_level_to_play().level_id, "world_01_level_001", "fresh save: the first level")
	(app.current_screen() as HomeScreen).continue_requested.emit()
	assert_eq(app.current_screen_name(), AppRoot.GAMEPLAY)
	assert_eq(_gameplay(app).get_session().get_level().id, "world_01_level_001")
	app.progress().record_completion("world_01_level_001", 0)
	assert_eq(app.next_level_to_play().level_id, "world_01_level_002", "then the first unsealed, unlocked level")
	app.free()


func test_campaign_pages_through_worlds() -> void:
	var app := _spawn()
	app.show_level_select()
	var screen := app.current_screen() as LevelSelectScreen
	assert_eq(screen.current_world_index(), 0, "opens on the world with the next level to play")
	assert_true(screen.level_button("world_01_level_001").is_visible_in_tree())
	assert_false(screen.level_button("world_02_level_007").is_visible_in_tree())
	screen.show_world(1)
	assert_eq(screen.current_world_index(), 1)
	assert_false(screen.level_button("world_01_level_001").is_visible_in_tree())
	assert_true(screen.level_button("world_02_level_007").is_visible_in_tree())
	screen.show_world(99)
	assert_eq(screen.current_world_index(), app.catalog().worlds.size() - 1, "paging is clamped")
	app.free()


func test_choosing_a_level_starts_gameplay_with_that_level() -> void:
	var app := _spawn()
	app.show_level_select()
	(app.current_screen() as LevelSelectScreen).level_button("world_05_reflector_logic").pressed.emit()
	assert_eq(app.current_screen_name(), AppRoot.GAMEPLAY)
	assert_eq(_gameplay(app).get_session().get_level().id, "world_05_reflector_logic")
	assert_false(_gameplay(app).quit_on_leave, "inside the app, Leave returns to level select")
	app.free()


func test_leave_returns_to_level_select() -> void:
	var app := _spawn()
	app.start_level("world_01_level_002")
	var gameplay := _gameplay(app)
	gameplay.handle_back()
	gameplay.get_hud().leave_dialog().leave_requested.emit()
	assert_eq(app.current_screen_name(), AppRoot.LEVEL_SELECT)
	app.free()


func test_back_from_level_select_goes_home_then_exits() -> void:
	var app := _spawn()
	app.show_level_select()
	app.handle_back()
	assert_eq(app.current_screen_name(), AppRoot.HOME)
	assert_eq(_exits, 0)
	app.handle_back()
	assert_eq(_exits, 1, "Back on home exits the app")
	app.free()


func test_back_in_gameplay_is_left_to_the_gameplay_controller() -> void:
	var app := _spawn()
	app.start_level("world_01_level_002")
	app.handle_back()
	assert_eq(app.current_screen_name(), AppRoot.GAMEPLAY)
	app.free()


# --- Completion -------------------------------------------------------------------

func test_completion_card_offers_next_level() -> void:
	var app := _spawn()
	app.start_level("world_01_level_001")
	var gameplay := _gameplay(app)
	var card := gameplay.get_hud().completion_card()
	assert_false(card.visible)
	_solve(gameplay, [PuzzleAction.run_core(), PuzzleAction.run_core()])
	assert_true(card.visible)
	assert_eq(card.summary_text(), "Actions 0  ·  Target 0  ·  Target met")
	assert_true(card.has_next_button())
	card.next_button().pressed.emit()
	assert_eq(app.current_screen_name(), AppRoot.GAMEPLAY)
	assert_eq(app.current_level_id(), "world_01_level_002")
	assert_false(_gameplay(app).get_hud().completion_card().visible, "the next level starts fresh")
	app.free()


func test_last_level_has_no_next_button_and_returns_to_levels() -> void:
	var app := _spawn()
	var ids := _catalog_ids(app.catalog())
	var last := ids[ids.size() - 1]
	app.start_level(last)
	var gameplay := _gameplay(app)
	# Play the solver's own solution, whatever the last level currently is.
	_solve(gameplay, PuzzleSolver.solve(gameplay.get_session().get_level()).solution)
	var card := gameplay.get_hud().completion_card()
	assert_true(card.visible)
	assert_false(card.has_next_button(), "%s is the last level" % last)
	card.levels_button().pressed.emit()
	assert_eq(app.current_screen_name(), AppRoot.LEVEL_SELECT)
	app.free()


func test_undo_after_completion_hides_card() -> void:
	var app := _spawn()
	app.start_level("world_01_level_001")
	var gameplay := _gameplay(app)
	_solve(gameplay, [PuzzleAction.run_core()])
	gameplay.request_undo()
	assert_false(gameplay.get_hud().completion_card().visible)
	app.free()
