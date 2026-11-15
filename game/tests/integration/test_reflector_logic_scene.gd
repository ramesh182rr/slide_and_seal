extends TestCase
## M7b: energy routing in the 3D scene, on "Reflector Logic".
## Emitter (0,0) fires right; mirror_top (5,0) starts "/" (beam leaves the board); flipped "\" it
## sends the beam down to mirror_low (5,2), which must become "/" to send it left to the receiver
## (2,2) that opens gate_seal (4,5) on the core's corridor.

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"
const LEVEL := "res://data/levels/world_05_reflector_logic.json"


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


func _assert_energy_visuals_match_state(scene: GameplayController, context: String) -> void:
	var state := scene.get_session().get_state()
	for reflector_id: String in state.reflector_slash.keys():
		assert_true(is_equal_approx(_fixtures(scene).reflector_pivot(reflector_id).rotation.y,
			MechanismFixtures3D.reflector_yaw(state.reflector_slash[reflector_id])), "%s — %s" % [reflector_id, context])
	assert_eq(_fixtures(scene).is_lit("receiver_gate"), state.powered_receivers.has("receiver_gate"),
		"receiver lamp — " + context)
	var beam_cells := 0
	for beam: EnergyResolver.Beam in EnergyResolver.trace(scene.get_session().get_level(), state):
		beam_cells += beam.cells.size()
	assert_true(_fixtures(scene).beam_segment_count() >= beam_cells, "every traced cell is drawn — " + context)


func test_initial_beam_and_mirrors_match_state() -> void:
	var scene := _spawn()
	_assert_energy_visuals_match_state(scene, "initial")
	assert_eq(_fixtures(scene).beam_segment_count(), 6, "five traced cells plus the stub past the mirror")
	assert_false(_fixtures(scene).is_lit("receiver_gate"))
	scene.free()


func test_tapping_energy_fixtures_explains_them() -> void:
	var scene := _spawn()
	_tap_cell(scene, Vector2i(2, 2))
	assert_true(scene.get_hud().message_text().begins_with("Receiver A: on while an energy beam reaches it."),
		scene.get_hud().message_text())
	_tap_cell(scene, Vector2i(0, 0))
	assert_eq(scene.get_hud().message_text(), "Emitter: fires an energy beam.")
	_tap_cell(scene, Vector2i(5, 0))
	assert_eq(scene.get_hud().message_text(), "Mirrors cannot be flipped here.", "not before the checkpoint")
	scene.free()


func test_flip_panel_previews_the_new_beam() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	assert_eq(scene.get_hud().available_text(), "Available: Energy. Tap a mirror.")
	_tap_cell(scene, Vector2i(5, 0))
	assert_eq(scene.selected_target(), "reflector:mirror_top")
	var panel := scene.get_hud().mechanism_panel()
	assert_eq(panel.action_button(0).text, "Flip mirror")
	assert_false(panel.action_button(0).disabled)
	var key := scene.get_session().get_state().to_key()
	panel.action_button(0).button_down.emit()
	assert_true(scene.get_board().preview_ghost_count() > 0, "the new beam path is previewed")
	assert_eq(scene.get_session().get_state().to_key(), key, "preview must not commit")
	panel.action_button(0).button_up.emit()
	panel.action_button(0).pressed.emit()
	assert_false(scene.get_session().get_state().reflector_slash["mirror_top"])
	_assert_energy_visuals_match_state(scene, "after one flip")
	scene.free()


func test_full_level_through_taps() -> void:
	var scene := _spawn()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	var panel := scene.get_hud().mechanism_panel()
	_tap_cell(scene, Vector2i(5, 2))
	panel.action_button(0).pressed.emit()
	_tap_cell(scene, Vector2i(5, 0))
	panel.action_button(0).pressed.emit()
	var state := scene.get_session().get_state()
	assert_true(state.powered_receivers.has("receiver_gate"))
	assert_true(_fixtures(scene).is_lit("receiver_gate"))
	assert_true(is_equal_approx(_fixtures(scene).gate_node("gate_seal").position.y, MechanismFixtures3D.gate_y(true)))
	_assert_energy_visuals_match_state(scene, "both flipped")
	var finale := scene.request_action(PuzzleAction.run_core())
	assert_true(finale.is_ok(), finale.message)
	assert_eq(scene.get_session().get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(scene.get_session().get_state().mechanism_action_count, 2)
	scene.free()


func test_undo_restores_mirror_and_beam() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	var before := _fixtures(scene).beam_segment_count()
	scene.request_action(PuzzleAction.flip_reflector("mirror_top"))
	assert_ne(_fixtures(scene).beam_segment_count(), before)
	scene.request_undo()
	assert_eq(_fixtures(scene).beam_segment_count(), before)
	_assert_energy_visuals_match_state(scene, "after undo")
	scene.free()
