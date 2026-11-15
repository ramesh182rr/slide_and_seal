extends TestCase
## M8b: magnets in the 3D scene, on "Opposite Attraction".
## Block K (+) at (4,1) must reach the plate at (2,1) to open gate_seal (4,4). magnet_west (0,1)
## starts "+", magnet_east (6,1) starts "-". Each flip moves K one cell, and one magnet alone only
## alternates attract/repel, so both magnets are needed.

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"
const LEVEL := "res://data/levels/world_06_opposite_attraction.json"


func _spawn() -> GameplayController:
	var scene: GameplayController = (load(SCENE) as PackedScene).instantiate()
	scene.level_path = LEVEL
	scene.instant_playback = true
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene


func _fixtures(scene: GameplayController) -> MechanismFixtures3D:
	return scene.get_board().fixtures()


func _tap_cell(scene: GameplayController, cell: Vector2i) -> void:
	var at := scene.get_camera_rig().get_camera().unproject_position(BoardCoords.cell_to_world(cell))
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		scene.get_board_input().handle_event(event)


func _assert_magnets_match_state(scene: GameplayController, context: String) -> void:
	var state := scene.get_session().get_state()
	for magnet_id: String in state.magnet_positive.keys():
		assert_eq(_fixtures(scene).magnet_label(magnet_id),
			MechanismFixtures3D.polarity_symbol(state.magnet_positive[magnet_id]), "%s label — %s" % [magnet_id, context])
	var block := state.object_by_id("block_k")
	assert_eq(scene.get_board().object_node("block_k").position, BoardRenderer3D.object_world_position(block.position),
		"block K — " + context)


func test_polarity_is_shown_by_symbol_and_colour() -> void:
	var scene := _spawn()
	_assert_magnets_match_state(scene, "initial")
	assert_eq(_fixtures(scene).magnet_label("magnet_west"), "+")
	assert_eq(_fixtures(scene).magnet_label("magnet_east"), "\u2212", "true minus sign, not a hyphen")
	var marker := scene.get_board().object_node("block_k").get_node("Polarity") as Label3D
	assert_eq(marker.text, "+", "the block carries its polarity symbol")
	assert_eq(marker.modulate, Palette.POLARITY_RED)
	scene.free()


func test_taps_explain_magnets_and_magnetic_blocks() -> void:
	var scene := _spawn()
	_tap_cell(scene, Vector2i(0, 1))
	assert_eq(scene.get_hud().message_text(), "Magnets cannot be flipped here.")
	_tap_cell(scene, Vector2i(4, 1))
	assert_true(scene.get_hud().message_text().begins_with("Magnetic block (+)"), scene.get_hud().message_text())
	scene.free()


func test_magnet_panel_previews_and_flips() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	assert_eq(scene.get_hud().available_text(), "Available: Magnetism. Tap a magnet.")
	_tap_cell(scene, Vector2i(6, 1))
	assert_eq(scene.selected_target(), "magnet:magnet_east")
	var panel := scene.get_hud().mechanism_panel()
	assert_eq(panel.title_text(), "Magnet (\u2212)")
	assert_eq(panel.action_button(0).text, "Switch to +")
	var key := scene.get_session().get_state().to_key()
	panel.action_button(0).button_down.emit()
	assert_eq(scene.get_board().preview_ghost_count(), 1, "ghost of K one cell nearer the plate")
	assert_eq(scene.get_session().get_state().to_key(), key, "preview must not commit")
	panel.action_button(0).button_up.emit()
	panel.action_button(0).pressed.emit()
	assert_eq(scene.get_session().get_state().object_by_id("block_k").position, Vector2i(3, 1))
	assert_eq(panel.title_text(), "Magnet (+)", "the panel refreshes in place")
	_assert_magnets_match_state(scene, "after flipping east")
	scene.free()


func test_full_level_through_taps() -> void:
	var scene := _spawn()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	var panel := scene.get_hud().mechanism_panel()
	_tap_cell(scene, Vector2i(6, 1))
	panel.action_button(0).pressed.emit()
	_tap_cell(scene, Vector2i(0, 1))
	panel.action_button(0).pressed.emit()
	var state := scene.get_session().get_state()
	assert_eq(state.object_by_id("block_k").position, Vector2i(2, 1), "K rests on the plate")
	assert_true(is_equal_approx(_fixtures(scene).gate_node("gate_seal").position.y, MechanismFixtures3D.gate_y(true)))
	_assert_magnets_match_state(scene, "both flipped")
	var finale := scene.request_action(PuzzleAction.run_core())
	assert_true(finale.is_ok(), finale.message)
	assert_eq(scene.get_session().get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(scene.get_session().get_state().mechanism_action_count, 2)
	scene.free()


func test_one_magnet_alone_only_alternates() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	scene.request_action(PuzzleAction.flip_magnet("magnet_east"))
	assert_eq(scene.get_session().get_state().object_by_id("block_k").position, Vector2i(3, 1))
	scene.request_action(PuzzleAction.flip_magnet("magnet_east"))
	assert_eq(scene.get_session().get_state().object_by_id("block_k").position, Vector2i(4, 1),
		"flipping back attracts K to the east again")
	_assert_magnets_match_state(scene, "after flipping east twice")
	scene.free()
