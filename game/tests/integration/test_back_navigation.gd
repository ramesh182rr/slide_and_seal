extends TestCase
## Android Back / Escape: unwind one layer at a time, never quit without confirmation.

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"

var _left := 0


func _spawn() -> GameplayController:
	var scene: GameplayController = (load(SCENE) as PackedScene).instantiate()
	scene.level_path = "res://data/levels/retired/world_01_slice.json"  # The retired vertical slice: rich mechanics for scene tests.
	scene.instant_playback = true
	scene.quit_on_leave = false
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	_left = 0
	scene.leave_requested.connect(func() -> void: _left += 1)
	return scene


func test_quit_on_go_back_is_disabled() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"),
		"Godot must not quit on Back by itself; the game handles it")


func test_back_closes_panel_before_asking_to_leave() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	scene.select_object("block_a")
	scene.handle_back()
	assert_eq(scene.selected_target(), "", "first Back closes the mechanism panel")
	assert_false(scene.get_hud().leave_dialog().visible)
	scene.handle_back()
	assert_true(scene.get_hud().leave_dialog().visible, "second Back asks to leave")
	assert_eq(_left, 0)
	scene.free()


func test_dialog_covers_the_whole_screen() -> void:
	# Regression (seen on the Android emulator): a zero-size dialog neither dims nor blocks the board.
	var scene := _spawn()
	scene.handle_back()
	var dialog := scene.get_hud().leave_dialog()
	var screen := scene.get_viewport().get_visible_rect().size
	assert_eq(dialog.get_global_rect().size, screen, "dialog must cover the viewport to block input")
	assert_eq(dialog.mouse_filter, Control.MOUSE_FILTER_STOP)
	scene.free()


func test_back_again_dismisses_dialog_and_keeps_state() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	var key := scene.get_session().get_state().to_key()
	scene.handle_back()
	scene.handle_back()
	assert_false(scene.get_hud().leave_dialog().visible)
	assert_eq(scene.get_session().get_state().to_key(), key)
	assert_eq(_left, 0)
	scene.free()


func test_stay_closes_dialog() -> void:
	var scene := _spawn()
	scene.handle_back()
	scene.get_hud().leave_dialog().stay_requested.emit()
	assert_false(scene.get_hud().leave_dialog().visible)
	assert_eq(_left, 0)
	scene.free()


func test_leave_confirms_exit() -> void:
	var scene := _spawn()
	scene.handle_back()
	scene.get_hud().leave_dialog().leave_requested.emit()
	assert_eq(_left, 1)
	assert_false(scene.get_hud().leave_dialog().visible)
	scene.free()


func test_android_back_notification_routes_to_handler() -> void:
	var scene := _spawn()
	scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(scene.get_hud().leave_dialog().visible)
	scene.free()


func test_back_button_asks_before_leaving_an_unfinished_level() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	scene.select_object("block_a")
	var key := scene.get_session().get_state().to_key()
	scene.get_hud().back_button().pressed.emit()
	assert_true(scene.get_hud().leave_dialog().visible, "the on-screen Back asks straight away")
	assert_eq(scene.selected_target(), "", "and closes the panel behind the dialog")
	assert_eq(_left, 0)
	scene.get_hud().leave_dialog().leave_requested.emit()
	assert_eq(_left, 1)
	assert_eq(scene.get_session().get_state().to_key(), key, "leaving never changes the puzzle")
	scene.free()


func test_back_button_leaves_a_finished_level_at_once() -> void:
	var scene := _spawn()
	var solution := PuzzleSolver.solve(scene.get_session().get_level()).solution
	for action: PuzzleAction in solution:
		assert_true(scene.request_action(action).is_ok())
	assert_eq(scene.get_session().get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	scene.get_hud().back_button().pressed.emit()
	assert_eq(_left, 1, "nothing to lose: no question asked")
	assert_false(scene.get_hud().leave_dialog().visible)
	scene.free()


func test_back_button_is_on_screen_and_takes_input() -> void:
	var scene := _spawn()
	var back := scene.get_hud().back_button()
	assert_true(back.is_visible_in_tree())
	assert_eq(back.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(back.get_global_rect().size.x > 0.0)
	scene.free()
