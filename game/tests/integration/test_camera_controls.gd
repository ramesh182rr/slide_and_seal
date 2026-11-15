extends TestCase
## M9a view controls (D-031, D-032): free rotation, zoom and pan of the board view.
## The view is presentation only, so every test also checks the puzzle state is untouched,
## and that picking, swipes and the arrow pad follow the new projection.

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"
const LEVEL := "res://data/levels/retired/world_01_slice.json"


func _spawn() -> GameplayController:
	var scene: GameplayController = (load(SCENE) as PackedScene).instantiate()
	scene.level_path = LEVEL
	scene.instant_playback = true
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene


func _rig(scene: GameplayController) -> CameraRig:
	return scene.get_camera_rig()


func _block_screen(scene: GameplayController, cell: Vector2i) -> Vector2:
	var top := BoardRenderer3D.object_world_position(cell) + Vector3(0, BoardRenderer3D.BLOCK_SIZE * 0.5, 0)
	return _rig(scene).get_camera().unproject_position(top)


func _touch(scene: GameplayController, index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	scene.get_board_input().handle_event(event)


func _drag(scene: GameplayController, index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	scene.get_board_input().handle_event(event)


func _mouse(scene: GameplayController, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	scene.get_board_input().handle_event(event)


func _near(a: float, b: float, epsilon: float = 0.01) -> bool:
	return absf(a - b) <= epsilon


func test_default_view() -> void:
	var scene := _spawn()
	assert_true(_near(_rig(scene).yaw_degrees(), CameraRig.DEFAULT_YAW_DEGREES))
	assert_true(_near(_rig(scene).zoom_level(), 1.0))
	assert_eq(_rig(scene).pan_offset(), Vector2.ZERO)
	scene.free()


func test_button_turn_rotates_view_and_swipe_mapping_follows() -> void:
	var scene := _spawn()
	var key := scene.get_session().get_state().to_key()
	var before := _rig(scene).screen_vector(Grid.Direction.UP)
	scene.get_hud().view_button(IconButton.Icon.ROTATE_RIGHT).pressed.emit()
	assert_true(_near(_rig(scene).yaw_degrees(), fposmod(CameraRig.DEFAULT_YAW_DEGREES + 90.0, 360.0)),
		"instant mode turns a full 90 degrees: %s" % _rig(scene).yaw_degrees())
	var after := _rig(scene).screen_vector(Grid.Direction.UP)
	# Not exactly perpendicular on screen: the tilted view foreshortens the board.
	assert_true(before.dot(after) < 0.5, "grid up now points a quarter turn away: %s → %s" % [before, after])
	for direction: int in 4:
		var drag := _rig(scene).screen_vector(direction as Grid.Direction) * 100.0
		assert_eq(scene.get_board_input().classify(drag), direction as Grid.Direction, "swipe follows the view")
	# Screen y points down, so a growing screen angle means the board turned clockwise.
	assert_true(wrapf(after.angle() - before.angle(), -PI, PI) > 0.0, "rotate-right turns the board clockwise")
	scene.get_hud().view_button(IconButton.Icon.ROTATE_LEFT).pressed.emit()
	assert_true(_near(_rig(scene).yaw_degrees(), CameraRig.DEFAULT_YAW_DEGREES))
	assert_eq(scene.get_session().get_state().to_key(), key, "the view never changes the puzzle")
	scene.free()


func test_arrow_pad_follows_rotation() -> void:
	var scene := _spawn()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	scene.select_object("block_a")
	var panel := scene.get_hud().mechanism_panel()
	_rig(scene).rotate_view(70.0)
	for direction: Grid.Direction in [Grid.Direction.UP, Grid.Direction.RIGHT, Grid.Direction.DOWN]:
		var expected := _rig(scene).screen_vector(direction).angle()
		var actual := panel.option_button(direction).screen_angle
		assert_true(_near(wrapf(actual - expected, -PI, PI), 0.0), "arrow %d follows the view" % direction)
	assert_eq(scene.selected_target(), "object:block_a", "rotating keeps the selection")
	scene.free()


func test_picking_still_hits_blocks_after_rotate_zoom_and_pan() -> void:
	var scene := _spawn()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	_rig(scene).rotate_view(133.0)
	_rig(scene).zoom_by(1.8)
	_rig(scene).pan_by_screen(Vector2(40, -30))
	var at := _block_screen(scene, Vector2i(3, 1))
	_mouse(scene, at, true)
	_mouse(scene, at, false)
	assert_eq(scene.selected_target(), "object:block_a")
	scene.free()


func test_zoom_and_pan_are_clamped_and_reset_restores_defaults() -> void:
	var scene := _spawn()
	_rig(scene).zoom_by(100.0)
	assert_true(_near(_rig(scene).zoom_level(), CameraRig.MAX_ZOOM))
	_rig(scene).zoom_by(0.0001)
	assert_true(_near(_rig(scene).zoom_level(), CameraRig.MIN_ZOOM))
	_rig(scene).zoom_by(2.0)
	_rig(scene).pan_by_screen(Vector2(100000, 100000))
	var pan := _rig(scene).pan_offset()
	assert_true(pan.length() > 0.0 and pan.length() < 50.0, "pan stays near the board: %s" % pan)
	_rig(scene).rotate_view(33.0)
	scene.get_hud().view_button(IconButton.Icon.RESET_VIEW).pressed.emit()
	assert_true(_near(_rig(scene).yaw_degrees(), CameraRig.DEFAULT_YAW_DEGREES))
	assert_true(_near(_rig(scene).zoom_level(), 1.0))
	assert_eq(_rig(scene).pan_offset(), Vector2.ZERO)
	scene.free()


func test_zoom_buttons_and_wheel_zoom() -> void:
	var scene := _spawn()
	scene.get_hud().view_button(IconButton.Icon.ZOOM_IN).pressed.emit()
	assert_true(_near(_rig(scene).zoom_level(), HudController.VIEW_ZOOM_STEP))
	scene.get_hud().view_button(IconButton.Icon.ZOOM_OUT).pressed.emit()
	assert_true(_near(_rig(scene).zoom_level(), 1.0))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	assert_true(scene.get_board_input().handle_event(wheel))
	assert_true(_near(_rig(scene).zoom_level(), BoardInput.WHEEL_ZOOM_STEP))
	assert_eq(scene.selected_target(), "", "wheel never selects")
	scene.free()


func test_pinch_zooms_and_twist_rotates() -> void:
	var scene := _spawn()
	var key := scene.get_session().get_state().to_key()
	var centre := Vector2(540, 900)
	_touch(scene, 0, centre + Vector2(-100, 0), true)
	_touch(scene, 1, centre + Vector2(100, 0), true)
	assert_true(scene.get_board_input().is_gesture_active())
	# Spread the fingers to twice the distance: zoom doubles.
	_drag(scene, 0, centre + Vector2(-200, 0))
	_drag(scene, 1, centre + Vector2(200, 0))
	assert_true(_near(_rig(scene).zoom_level(), 2.0), "zoom %s" % _rig(scene).zoom_level())
	# Twist clockwise on screen by 30 degrees around the midpoint.
	var yaw := _rig(scene).yaw_degrees()
	var offset := Vector2(200, 0).rotated(deg_to_rad(30.0))
	_drag(scene, 0, centre - offset)
	_drag(scene, 1, centre + offset)
	var turned := wrapf(_rig(scene).yaw_degrees() - yaw, -180.0, 180.0)
	assert_true(_near(absf(turned), 30.0, 0.5), "free rotation by the twist angle: %s" % turned)
	_touch(scene, 0, centre - offset, false)
	_touch(scene, 1, centre + offset, false)
	assert_false(scene.get_board_input().is_gesture_active())
	assert_eq(scene.get_session().get_state().to_key(), key)
	scene.free()


func test_twist_direction_matches_fingers() -> void:
	# A clockwise finger twist turns the board clockwise on screen: the screen angle of
	# grid "right" increases (screen y points down) by about the twist angle.
	var scene := _spawn()
	var before := _rig(scene).screen_vector(Grid.Direction.RIGHT).angle()
	var centre := Vector2(540, 900)
	_touch(scene, 0, centre + Vector2(-150, 0), true)
	_touch(scene, 1, centre + Vector2(150, 0), true)
	var offset := Vector2(150, 0).rotated(deg_to_rad(20.0))
	_drag(scene, 0, centre - offset)
	_drag(scene, 1, centre + offset)
	var after := _rig(scene).screen_vector(Grid.Direction.RIGHT).angle()
	assert_true(wrapf(after - before, -PI, PI) > deg_to_rad(5.0),
		"board turned with the fingers: %s → %s" % [before, after])
	scene.free()


func test_two_finger_drag_pans() -> void:
	var scene := _spawn()
	_rig(scene).zoom_by(2.0)
	var probe := BoardCoords.board_center(scene.get_session().get_level().board_size)
	var start := _rig(scene).get_camera().unproject_position(probe)
	_touch(scene, 0, Vector2(400, 900), true)
	_touch(scene, 1, Vector2(600, 900), true)
	_drag(scene, 0, Vector2(400, 960))
	_drag(scene, 1, Vector2(600, 960))
	var moved := _rig(scene).get_camera().unproject_position(probe) - start
	assert_true(moved.y > 30.0 and absf(moved.x) < 10.0, "the board follows the fingers: %s" % moved)
	scene.free()


func test_gesture_suppresses_tap_and_cancels_swipe_preview() -> void:
	var scene := _spawn()
	assert_true(scene.request_action(PuzzleAction.run_core()).is_ok())
	var key := scene.get_session().get_state().to_key()
	var at := _block_screen(scene, Vector2i(3, 1))
	# First finger starts a swipe on block A (emulated mouse + touch), passing the threshold.
	_touch(scene, 0, at, true)
	_mouse(scene, at, true)
	var motion := InputEventMouseMotion.new()
	motion.position = at + _rig(scene).screen_vector(Grid.Direction.UP) * 120.0
	scene.get_board_input().handle_event(motion)
	assert_eq(scene.get_board().preview_ghost_count(), 1, "swipe preview shown")
	# A second finger turns it into a view gesture: the preview is dropped.
	_touch(scene, 1, at + Vector2(200, 0), true)
	assert_eq(scene.get_board().preview_ghost_count(), 0, "gesture cancels the swipe preview")
	_drag(scene, 1, at + Vector2(260, 40))
	# Lifting: the emulated mouse release must not commit a push or select anything.
	_mouse(scene, motion.position, false)
	_touch(scene, 0, motion.position, false)
	_touch(scene, 1, at + Vector2(260, 40), false)
	assert_eq(scene.get_session().get_state().to_key(), key, "no push committed")
	assert_eq(scene.selected_target(), "", "no stray tap selection")
	# The next ordinary tap works again.
	var again := _block_screen(scene, Vector2i(3, 1))
	_touch(scene, 0, again, true)
	_mouse(scene, again, true)
	_mouse(scene, again, false)
	_touch(scene, 0, again, false)
	assert_eq(scene.selected_target(), "object:block_a")
	scene.free()


func test_keys_turn_and_reset() -> void:
	var scene := _spawn()
	var key_e := InputEventKey.new()
	key_e.keycode = KEY_E
	key_e.pressed = true
	assert_true(scene.get_board_input().handle_event(key_e))
	assert_true(_near(_rig(scene).yaw_degrees(), fposmod(CameraRig.DEFAULT_YAW_DEGREES + 90.0, 360.0)))
	var key_r := InputEventKey.new()
	key_r.keycode = KEY_R
	key_r.pressed = true
	scene.get_board_input().handle_event(key_r)
	assert_true(_near(_rig(scene).yaw_degrees(), CameraRig.DEFAULT_YAW_DEGREES))
	scene.free()


func test_view_gestures_work_during_playback_lock() -> void:
	var scene := _spawn()
	scene.get_board_input().enabled = false
	scene.get_hud().view_button(IconButton.Icon.ZOOM_IN).pressed.emit()
	_rig(scene).rotate_view(10.0)
	assert_true(_rig(scene).zoom_level() > 1.0)
	scene.free()
