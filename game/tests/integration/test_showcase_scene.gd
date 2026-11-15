extends TestCase
## M5c: switches, gates and portals in the 3D scene, on the showcase level.
## Layout: lever "lever_gate" (1,0) opens gate_a (3,1); plate "plate_gate" (6,2) opens gate_b (5,4)
## when block_k (6,1) is pushed onto it; lever "lever_portal" (6,5) powers portal_in (4,5) → portal_out (1,4).

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"
const LEVEL := "res://data/levels/world_05_showcase.json"


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


func _gate_open_visual(scene: GameplayController, gate_id: String) -> bool:
	return is_equal_approx(_fixtures(scene).gate_node(gate_id).position.y, MechanismFixtures3D.gate_y(true))


func _assert_fixtures_match_state(scene: GameplayController, context: String) -> void:
	var level := scene.get_session().get_level()
	var state := scene.get_session().get_state()
	for gate: GateDefinition in level.gates:
		assert_eq(_gate_open_visual(scene, gate.id), SwitchGateResolver.is_gate_open(level, state, gate),
			"%s visual — %s" % [gate.id, context])
	for switch_def: SwitchDefinition in level.switches:
		assert_eq(_fixtures(scene).is_lit(switch_def.id), SwitchGateResolver.is_switch_on(state, switch_def),
			"%s lamp — %s" % [switch_def.id, context])


func test_link_symbols_pair_switches_with_what_they_power() -> void:
	var scene := _spawn()
	var fixtures := _fixtures(scene)
	assert_eq(fixtures.symbol("gate_a"), "A")
	assert_eq(fixtures.symbol("gate_b"), "B")
	assert_eq(fixtures.symbol("lever_gate"), "A")
	assert_eq(fixtures.symbol("plate_gate"), "B")
	assert_eq(fixtures.symbol("portal_in"), "1")
	assert_eq(fixtures.symbol("portal_out"), "1")
	assert_eq(fixtures.symbol("lever_portal"), "1")
	assert_eq(fixtures.label_text("lever_gate"), "A", "labels show the symbols")
	scene.free()


func test_initial_fixtures_match_state() -> void:
	var scene := _spawn()
	_assert_fixtures_match_state(scene, "initial")
	assert_false(_gate_open_visual(scene, "gate_a"))
	assert_false(_fixtures(scene).is_lit("portal_in"))
	scene.free()


func test_tap_lever_opens_toggle_panel_with_gate_preview() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	_tap_cell(scene, Vector2i(1, 0))
	assert_eq(scene.selected_target(), "switch:lever_gate")
	var panel := scene.get_hud().mechanism_panel()
	assert_true(panel.visible)
	assert_true(panel.action_button().visible)
	assert_false(panel.action_button().disabled)
	assert_eq(panel.action_button().text, "Switch on")
	var key := scene.get_session().get_state().to_key()
	panel.action_button().button_down.emit()
	assert_eq(scene.get_board().preview_ghost_count(), 1, "ghost of gate A in its open position")
	assert_eq(scene.get_session().get_state().to_key(), key, "preview must not commit")
	panel.action_button().button_up.emit()
	panel.action_button().pressed.emit()  # The real button signal (regression guard for in-place refresh).
	assert_true(scene.get_session().get_state().toggle_states["lever_gate"])
	assert_true(_gate_open_visual(scene, "gate_a"))
	assert_eq(panel.action_button().text, "Switch off")
	_assert_fixtures_match_state(scene, "after toggle")
	scene.free()


func test_tap_pressure_plate_and_gate_explain_themselves() -> void:
	var scene := _spawn()
	_tap_cell(scene, Vector2i(6, 2))
	assert_eq(scene.selected_target(), "")
	assert_true(scene.get_hud().message_text().begins_with("Pressure plate B"), scene.get_hud().message_text())
	_tap_cell(scene, Vector2i(3, 1))
	assert_true(scene.get_hud().message_text().begins_with("Gate A"), scene.get_hud().message_text())
	_tap_cell(scene, Vector2i(4, 5))
	assert_true(scene.get_hud().message_text().begins_with("Portal 1"), scene.get_hud().message_text())
	scene.free()


func test_lever_unavailable_outside_switch_checkpoints() -> void:
	var scene := _spawn()
	_tap_cell(scene, Vector2i(1, 0))
	assert_eq(scene.selected_target(), "")
	assert_eq(scene.get_hud().message_text(), "Switches cannot be used here.")
	scene.free()


func test_full_showcase_solved_through_taps_and_swipes() -> void:
	var scene := _spawn()
	var panel := scene.get_hud().mechanism_panel()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	_tap_cell(scene, Vector2i(1, 0))
	panel.action_button().pressed.emit()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	assert_eq(scene.get_session().get_state().reached_checkpoint_ids[-1], "cp_plate")
	# Swipe block K down onto the plate.
	var camera := scene.get_camera_rig().get_camera()
	var top := BoardRenderer3D.object_world_position(Vector2i(6, 1)) + Vector3(0, BoardRenderer3D.BLOCK_SIZE * 0.5, 0)
	var start := camera.unproject_position(top)
	var finish := start + scene.get_camera_rig().screen_vector(Grid.Direction.DOWN) * 120.0
	for event: InputEvent in _swipe_events(start, finish):
		scene.get_board_input().handle_event(event)
	assert_eq(scene.get_session().get_state().object_by_id("block_k").position, Vector2i(6, 2))
	assert_true(_gate_open_visual(scene, "gate_b"))
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	assert_eq(scene.request_action(PuzzleAction.run_core()).failure, ActionResult.Failure.ROUTE_BLOCKED,
		"portal 1 is unpowered")
	_tap_cell(scene, Vector2i(6, 5))
	panel.action_button().pressed.emit()
	assert_true(_fixtures(scene).is_lit("portal_in"))
	assert_true(_fixtures(scene).is_lit("portal_out"))
	var finale := scene.request_action(PuzzleAction.run_core())
	assert_true(finale.is_ok(), finale.message)
	assert_eq(finale.travel.portal_steps.size(), 1)
	var state := scene.get_session().get_state()
	assert_eq(state.phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(state.mechanism_action_count, 3)
	assert_eq(scene.get_board().core_node().position, BoardRenderer3D.core_world_position(Vector2i(2, 6)))
	_assert_fixtures_match_state(scene, "completed")
	scene.free()


func test_undo_restores_fixture_visuals() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	scene.request_action(PuzzleAction.toggle_switch("lever_gate"))
	assert_true(_gate_open_visual(scene, "gate_a"))
	scene.request_undo()
	assert_false(_gate_open_visual(scene, "gate_a"))
	_assert_fixtures_match_state(scene, "after undo")
	scene.free()


static func _swipe_events(start: Vector2, finish: Vector2) -> Array[InputEvent]:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	return [press, motion, release]
