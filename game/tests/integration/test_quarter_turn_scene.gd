extends TestCase
## M6b: rotating sections in the 3D scene, on "Quarter Turn".
## Layout: route_in (0,3)→(2,3) ends beside turntable (3,2) 3x3 (clockwise only); the L track piece
## starts top→right; two clockwise turns make it left→bottom, joining route_out (4,5)→(6,6).
## A fixed crate sits on the turntable's bottom-right corner.

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"
const LEVEL := "res://data/levels/world_06_quarter_turn.json"


func _spawn() -> GameplayController:
	var scene: GameplayController = (load(SCENE) as PackedScene).instantiate()
	scene.level_path = LEVEL
	scene.instant_playback = true
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene


func _tap_cell(scene: GameplayController, cell: Vector2i) -> void:
	var at := scene.get_camera_rig().get_camera().unproject_position(BoardCoords.cell_to_world(cell))
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		scene.get_board_input().handle_event(event)


func _assert_platform_matches_state(scene: GameplayController, context: String) -> void:
	var state := scene.get_session().get_state()
	var pivot := scene.get_board().section_pivot("turntable")
	assert_true(is_equal_approx(pivot.rotation.y, BoardRenderer3D.section_yaw(state.section_turns["turntable"])),
		"platform yaw — " + context)
	var crate := state.object_by_id("crate")
	assert_eq(scene.get_board().object_node("crate").position, BoardRenderer3D.object_world_position(crate.position),
		"crate — " + context)


func test_track_and_floor_inside_ride_the_platform() -> void:
	var scene := _spawn()
	var pivot := scene.get_board().section_pivot("turntable")
	assert_not_null(pivot)
	# Floor tiles and the track inlay are merged into static batches on the pivot, so they turn with it.
	var batches := scene.get_board().static_batches(pivot)
	var names := PackedStringArray()
	for batch: MeshInstance3D in batches:
		names.append(String(batch.name).get_slice("_", 1))
	assert_true(names.has("floor") and names.has("route"), "floor and track inlay ride the pivot: %s" % names)
	var vertices := 0
	for batch: MeshInstance3D in batches:
		vertices += batch.mesh.surface_get_array_len(0)
	var box_vertices := BoxMesh.new().get_mesh_arrays()[Mesh.ARRAY_VERTEX].size() as int
	assert_true(vertices >= 9 * box_vertices, "all 9 floor tiles are in the pivot's batches")
	_assert_platform_matches_state(scene, "initial")
	scene.free()


func test_tap_section_before_checkpoint_explains() -> void:
	var scene := _spawn()
	_tap_cell(scene, Vector2i(3, 4))
	assert_eq(scene.selected_target(), "")
	assert_eq(scene.get_hud().message_text(), "Sections cannot be turned here.")
	scene.free()


func test_panel_offers_only_the_allowed_direction_and_previews_the_track() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	assert_eq(scene.get_hud().available_text(), "Available: Rotation. Tap a rotating section.")
	_tap_cell(scene, Vector2i(3, 4))
	assert_eq(scene.selected_target(), "section:turntable")
	var panel := scene.get_hud().mechanism_panel()
	assert_true(panel.action_button(0).visible)
	assert_eq(panel.action_button(0).text, "Turn clockwise")
	assert_false(panel.action_button(0).disabled)
	assert_false(panel.action_button(1).visible, "the turntable is clockwise-only")
	var key := scene.get_session().get_state().to_key()
	panel.action_button(0).button_down.emit()
	assert_eq(scene.get_board().preview_ghost_count(), 4, "three track pads plus the crate's new cell")
	assert_eq(scene.get_session().get_state().to_key(), key, "preview must not commit")
	panel.action_button(0).button_up.emit()
	assert_eq(scene.get_board().preview_ghost_count(), 0)
	panel.action_button(0).pressed.emit()
	assert_eq(scene.get_session().get_state().section_turns["turntable"], 1)
	assert_eq(scene.get_session().get_state().object_by_id("crate").position, Vector2i(3, 4))
	_assert_platform_matches_state(scene, "after one turn")
	assert_true(panel.visible, "the panel stays for the next turn")
	scene.free()


func test_full_level_through_taps() -> void:
	var scene := _spawn()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	_tap_cell(scene, Vector2i(3, 4))
	var button := scene.get_hud().mechanism_panel().action_button(0)
	button.pressed.emit()
	button.pressed.emit()
	_assert_platform_matches_state(scene, "after two turns")
	var finale := scene.request_action(PuzzleAction.run_core())
	assert_true(finale.is_ok(), finale.message)
	var state := scene.get_session().get_state()
	assert_eq(state.phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(state.mechanism_action_count, 2)
	assert_eq(finale.travel.path.slice(0, 3), [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)] as Array[Vector2i],
		"from the checkpoint to the corridor's end, then into the turned L from the left")
	assert_eq(scene.get_board().core_node().position, BoardRenderer3D.core_world_position(Vector2i(6, 6)))
	scene.free()


func test_undo_turns_the_platform_back() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	scene.request_action(PuzzleAction.rotate_section("turntable", true))
	scene.request_undo()
	assert_eq(scene.get_session().get_state().section_turns["turntable"], 0)
	_assert_platform_matches_state(scene, "after undo")
	scene.free()
