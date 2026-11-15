extends TestCase
## M3b interaction (decision D-012): picking, tap-to-select panel, hold-to-preview, swipe.
## Drives the real gameplay scene with synthetic pointer events at projected screen positions.

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"
const UP := Grid.Direction.UP
const RIGHT := Grid.Direction.RIGHT
const DOWN := Grid.Direction.DOWN
const LEFT := Grid.Direction.LEFT


func _spawn() -> GameplayController:
	var scene: GameplayController = (load(SCENE) as PackedScene).instantiate()
	scene.instant_playback = true
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene


func _camera(scene: GameplayController) -> Camera3D:
	return scene.get_camera_rig().get_camera()


## Screen position of the top face of the block at `cell`.
func _block_screen(scene: GameplayController, cell: Vector2i) -> Vector2:
	var top := BoardRenderer3D.object_world_position(cell) + Vector3(0, BoardRenderer3D.BLOCK_SIZE * 0.5, 0)
	return _camera(scene).unproject_position(top)


func _floor_screen(scene: GameplayController, cell: Vector2i) -> Vector2:
	return _camera(scene).unproject_position(BoardCoords.cell_to_world(cell))


func _press(scene: GameplayController, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	scene.get_board_input().handle_event(event)


func _move(scene: GameplayController, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	scene.get_board_input().handle_event(event)


func _tap(scene: GameplayController, at: Vector2) -> void:
	_press(scene, at, true)
	_press(scene, at, false)


func _swipe(scene: GameplayController, from: Vector2, direction: Grid.Direction) -> void:
	var to := from + scene.get_camera_rig().screen_vector(direction) * 120.0
	_press(scene, from, true)
	_move(scene, to)
	_press(scene, to, false)


func _to_checkpoint(scene: GameplayController, steps: Array[PuzzleAction]) -> void:
	for action: PuzzleAction in steps:
		assert_true(scene.request_action(action).is_ok())


# --- Picking and direction mapping --------------------------------------------

func test_picker_hits_every_block_and_empty_zone_cells() -> void:
	var scene := _spawn()
	var state := scene.get_session().get_state()
	for obj: MovableObject in state.objects:
		var hit := BoardPicker.pick(_camera(scene), _block_screen(scene, obj.position), scene.get_session().get_level(), state)
		assert_eq(hit.object_id, obj.id, "tap on %s" % obj.id)
	var floor_hit := BoardPicker.pick(_camera(scene), _floor_screen(scene, Vector2i(2, 3)), scene.get_session().get_level(), state)
	assert_eq(floor_hit.object_id, "")
	assert_true(floor_hit.has_cell)
	assert_eq(floor_hit.cell, Vector2i(2, 3))
	scene.free()


func test_swipe_classification_matches_camera_projection() -> void:
	var scene := _spawn()
	for direction: int in 4:
		var drag := scene.get_camera_rig().screen_vector(direction as Grid.Direction) * 100.0
		assert_eq(scene.get_board_input().classify(drag), direction as Grid.Direction)
	scene.free()


func test_panel_slots_match_screen_direction() -> void:
	assert_eq(MechanismPanel.slot_index(Vector2(0.78, -0.62)), 2, "up-right → top-right")
	assert_eq(MechanismPanel.slot_index(Vector2(0.78, 0.62)), 8, "down-right → bottom-right")
	assert_eq(MechanismPanel.slot_index(Vector2(-0.78, 0.62)), 6, "down-left → bottom-left")
	assert_eq(MechanismPanel.slot_index(Vector2(0.0, -1.0)), 1, "straight up → top-middle")


# --- Tap and panel ------------------------------------------------------------

func test_tap_block_where_push_unavailable_shows_message() -> void:
	var scene := _spawn()
	_tap(scene, _block_screen(scene, Vector2i(3, 1)))
	assert_eq(scene.selected_target(), "")
	assert_false(scene.get_hud().mechanism_panel().visible)
	assert_eq(scene.get_hud().message_text(), "Push is not available here.")
	scene.free()


func test_tap_block_opens_panel_with_valid_directions() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core()])
	_tap(scene, _block_screen(scene, Vector2i(3, 1)))
	assert_eq(scene.selected_target(), "object:block_a")
	assert_eq(scene.get_board().highlighted_object_id(), "block_a")
	var panel := scene.get_hud().mechanism_panel()
	assert_true(panel.visible)
	assert_true(panel.is_option_enabled(UP))
	assert_true(panel.is_option_enabled(DOWN))
	assert_true(panel.is_option_enabled(RIGHT))
	assert_false(panel.is_option_enabled(LEFT), "the core occupies the cell to the left")
	scene.free()


func test_hold_previews_without_committing_then_release_commits() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core()])
	scene.select_object("block_a")
	var key := scene.get_session().get_state().to_key()
	var panel := scene.get_hud().mechanism_panel()
	panel.direction_preview_started.emit(UP)
	assert_eq(scene.get_board().preview_ghost_count(), 1)
	assert_eq(scene.get_session().get_state().to_key(), key, "preview must not commit")
	panel.direction_preview_ended.emit()
	assert_eq(scene.get_board().preview_ghost_count(), 0)
	panel.direction_chosen.emit(UP)
	assert_eq(scene.get_session().get_state().object_by_id("block_a").position, Vector2i(3, 0))
	assert_eq(scene.selected_target(), "object:block_a", "selection stays for follow-up moves")
	scene.free()


func test_tap_empty_floor_clears_selection() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core()])
	scene.select_object("block_a")
	_tap(scene, _floor_screen(scene, Vector2i(6, 0)))
	assert_eq(scene.selected_target(), "")
	assert_false(scene.get_hud().mechanism_panel().visible)
	scene.free()


func test_zone_panel_offers_allowed_directions_and_disables_current() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core(), PuzzleAction.push("block_a", UP), PuzzleAction.run_core()])
	_tap(scene, _floor_screen(scene, Vector2i(2, 3)))
	assert_eq(scene.selected_target(), "zone:zone_upper")
	var panel := scene.get_hud().mechanism_panel()
	assert_true(panel.has_option(UP))
	assert_true(panel.has_option(DOWN))
	assert_false(panel.has_option(LEFT), "zone only allows up/down")
	assert_true(panel.is_option_enabled(UP))
	assert_false(panel.is_option_enabled(DOWN), "already pointing down")
	scene.free()


func test_selection_dropped_when_core_moves_to_context_without_it() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core()])
	scene.select_object("block_a")
	scene.commit_target_direction(UP)
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	assert_eq(scene.selected_target(), "", "cp_gravity does not allow push")
	assert_false(scene.get_hud().mechanism_panel().visible)
	scene.free()


# --- Swipe --------------------------------------------------------------------

func test_swipe_on_block_pushes_it() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core()])
	_swipe(scene, _block_screen(scene, Vector2i(3, 1)), UP)
	assert_eq(scene.get_session().get_state().object_by_id("block_a").position, Vector2i(3, 0))
	assert_eq(scene.get_board().preview_ghost_count(), 0)
	scene.free()


func test_swipe_on_zone_sets_gravity() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core(), PuzzleAction.push("block_a", UP), PuzzleAction.run_core()])
	_swipe(scene, _floor_screen(scene, Vector2i(2, 3)), UP)
	var state := scene.get_session().get_state()
	assert_eq(state.gravity_directions["zone_upper"], UP)
	assert_eq(state.object_by_id("block_b").position, Vector2i(3, 3))
	scene.free()


func test_swipe_preview_then_cancel_commits_nothing() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core()])
	var key := scene.get_session().get_state().to_key()
	var start := _block_screen(scene, Vector2i(3, 1))
	_press(scene, start, true)
	_move(scene, start + scene.get_camera_rig().screen_vector(UP) * 120.0)
	assert_eq(scene.get_board().preview_ghost_count(), 1, "dragging past the threshold previews")
	_move(scene, start + Vector2(5, 5))
	assert_eq(scene.get_board().preview_ghost_count(), 0, "returning cancels the preview")
	_press(scene, start + Vector2(5, 5), false)
	assert_eq(scene.get_session().get_state().to_key(), key, "a short drag is a tap, not a push")
	scene.free()


func test_invalid_swipe_reports_and_changes_nothing() -> void:
	var scene := _spawn()
	_to_checkpoint(scene, [PuzzleAction.run_core()])
	var key := scene.get_session().get_state().to_key()
	_swipe(scene, _block_screen(scene, Vector2i(3, 1)), LEFT)
	assert_eq(scene.get_session().get_state().to_key(), key)
	assert_ne(scene.get_hud().message_text(), "")
	scene.free()


func test_full_slice_solved_through_gestures() -> void:
	var scene := _spawn()
	var hud := scene.get_hud()
	assert_eq(hud.available_text(), "No mechanisms here: run the core.")
	scene.request_action(PuzzleAction.run_core())
	assert_eq(hud.available_text(), "Available: Push. Tap or swipe a block.")
	_swipe(scene, _block_screen(scene, Vector2i(3, 1)), UP)
	scene.request_action(PuzzleAction.run_core())
	_swipe(scene, _floor_screen(scene, Vector2i(2, 3)), UP)
	scene.request_action(PuzzleAction.run_core())
	_swipe(scene, _block_screen(scene, Vector2i(3, 6)), LEFT)
	_tap(scene, _floor_screen(scene, Vector2i(4, 6)))
	scene.get_hud().mechanism_panel().direction_chosen.emit(UP)
	scene.request_action(PuzzleAction.run_core())
	var state := scene.get_session().get_state()
	assert_eq(state.phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(state.mechanism_action_count, 4)
	assert_eq(hud.available_text(), "")
	scene.free()
