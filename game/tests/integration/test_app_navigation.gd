extends TestCase
## Menu skeleton (P-012): catalog integrity, Home → Level select → Gameplay, completion card, Back.

const APP_SCENE := "res://scenes/app/app_root.tscn"

var _exits := 0


func _spawn() -> AppRoot:
	var app: AppRoot = (load(APP_SCENE) as PackedScene).instantiate()
	app.instant_playback = true
	app.quit_on_exit = false
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	_exits = 0
	app.exit_requested.connect(func() -> void: _exits += 1)
	return app


func _gameplay(app: AppRoot) -> GameplayController:
	return app.current_screen() as GameplayController


func _solve(gameplay: GameplayController, actions: Array[PuzzleAction]) -> void:
	for action: PuzzleAction in actions:
		assert_true(gameplay.request_action(action).is_ok(), action.describe())


# --- Catalog ------------------------------------------------------------------

func test_catalog_loads_in_order_without_errors() -> void:
	var catalog := LevelCatalog.load_default()
	assert_eq(catalog.errors, PackedStringArray())
	var ids := PackedStringArray()
	for entry: LevelCatalog.Entry in catalog.entries:
		ids.append(entry.level_id)
	assert_eq(ids, PackedStringArray(["world_01_level_001", "world_01_slice", "world_05_showcase"]))
	assert_eq(catalog.worlds[0].title, "The Awakening")
	assert_eq(catalog.next_after("world_01_slice").level_id, "world_05_showcase")
	assert_null(catalog.next_after("world_05_showcase"))


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
	assert_eq(screen.listed_level_ids(), PackedStringArray(["world_01_level_001", "world_01_slice", "world_05_showcase"]))
	assert_eq(screen.level_button("world_01_slice").text, "2.  The Awakening — Vertical Slice")
	app.free()


func test_choosing_a_level_starts_gameplay_with_that_level() -> void:
	var app := _spawn()
	app.show_level_select()
	(app.current_screen() as LevelSelectScreen).level_button("world_05_showcase").pressed.emit()
	assert_eq(app.current_screen_name(), AppRoot.GAMEPLAY)
	assert_eq(_gameplay(app).get_session().get_level().id, "world_05_showcase")
	assert_false(_gameplay(app).quit_on_leave, "inside the app, Leave returns to level select")
	app.free()


func test_leave_returns_to_level_select() -> void:
	var app := _spawn()
	app.start_level("world_01_slice")
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
	app.start_level("world_01_slice")
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
	assert_eq(app.current_level_id(), "world_01_slice")
	assert_false(_gameplay(app).get_hud().completion_card().visible, "the next level starts fresh")
	app.free()


func test_last_level_has_no_next_button_and_returns_to_levels() -> void:
	var app := _spawn()
	app.start_level("world_05_showcase")
	var gameplay := _gameplay(app)
	_solve(gameplay, [
		PuzzleAction.run_core(), PuzzleAction.toggle_switch("lever_gate"), PuzzleAction.run_core(),
		PuzzleAction.push("block_k", Grid.Direction.DOWN), PuzzleAction.run_core(),
		PuzzleAction.toggle_switch("lever_portal"), PuzzleAction.run_core(),
	])
	var card := gameplay.get_hud().completion_card()
	assert_true(card.visible)
	assert_false(card.has_next_button())
	card.levels_button().pressed.emit()
	assert_eq(app.current_screen_name(), AppRoot.LEVEL_SELECT)
	app.free()


func test_undo_after_completion_hides_card() -> void:
	var app := _spawn()
	app.start_level("world_01_level_001")
	var gameplay := _gameplay(app)
	_solve(gameplay, [PuzzleAction.run_core(), PuzzleAction.run_core()])
	gameplay.request_undo()
	assert_false(gameplay.get_hud().completion_card().visible)
	app.free()
