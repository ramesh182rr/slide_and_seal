extends TestCase
## The gameplay scene: the 3D board must always mirror the committed simulation state,
## and the HUD must reflect availability. Runs with instant playback (no animation).

const SCENE := "res://scenes/gameplay/gameplay_root.tscn"
const UP := Grid.Direction.UP
const LEFT := Grid.Direction.LEFT


func _spawn() -> GameplayController:
	var scene: GameplayController = (load(SCENE) as PackedScene).instantiate()
	scene.level_path = "res://data/levels/retired/world_01_slice.json"  # The retired vertical slice: rich mechanics for scene tests.
	scene.instant_playback = true
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene


func _assert_board_matches_state(scene: GameplayController, context: String) -> void:
	var session := scene.get_session()
	var state := session.get_state()
	var board := scene.get_board()
	var core_cell := PuzzleSimulator.core_position(session.get_level(), state)
	assert_eq(board.core_node().position, BoardRenderer3D.core_world_position(core_cell), "core — " + context)
	for obj: MovableObject in state.objects:
		assert_eq(board.object_node(obj.id).position, BoardRenderer3D.object_world_position(obj.position),
			"%s — %s" % [obj.id, context])
	for zone_id: String in state.gravity_directions.keys():
		var expected_yaw := BoardCoords.direction_yaw(state.gravity_directions[zone_id])
		for pivot: Node3D in board.zone_chevrons(zone_id):
			assert_true(is_equal_approx(pivot.rotation.y, expected_yaw), "%s arrows — %s" % [zone_id, context])


func test_scene_builds_board_for_initial_state() -> void:
	var scene := _spawn()
	assert_not_null(scene.get_session(), "level must load")
	assert_eq(scene.get_session().get_level().id, "world_01_slice")
	_assert_board_matches_state(scene, "initial")
	assert_eq(scene.get_board().zone_chevrons("zone_upper").size(), 6)
	scene.free()


func test_board_mirrors_state_through_full_solution() -> void:
	var scene := _spawn()
	var solution: Array[PuzzleAction] = [
		PuzzleAction.run_core(),
		PuzzleAction.push("block_a", UP),
		PuzzleAction.run_core(),
		PuzzleAction.set_gravity("zone_upper", UP),
		PuzzleAction.run_core(),
		PuzzleAction.push("block_f", LEFT),
		PuzzleAction.set_gravity("zone_lower", UP),
		PuzzleAction.run_core(),
	]
	for i: int in solution.size():
		var result := scene.request_action(solution[i])
		assert_true(result != null and result.is_ok(), "step %d" % i)
		assert_false(scene.is_busy(), "instant playback finishes synchronously")
		_assert_board_matches_state(scene, "after step %d" % i)
	assert_eq(scene.get_session().get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(scene.get_hud().status_text(), "Seal complete.")
	assert_false(scene.get_hud().is_run_enabled())
	scene.free()


func test_rejected_action_shows_message_and_changes_nothing() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	var key := scene.get_session().get_state().to_key()
	var result := scene.request_action(PuzzleAction.run_core())
	assert_eq(result.failure, ActionResult.Failure.ROUTE_BLOCKED)
	assert_eq(scene.get_session().get_state().to_key(), key)
	assert_ne(scene.get_hud().message_text(), "")
	assert_false(scene.get_hud().is_run_enabled(), "Resume is disabled while the route is blocked")
	_assert_board_matches_state(scene, "after rejection")
	scene.free()


func test_undo_and_restart_resync_board() -> void:
	var scene := _spawn()
	scene.request_action(PuzzleAction.run_core())
	scene.request_action(PuzzleAction.push("block_a", UP))
	scene.request_undo()
	_assert_board_matches_state(scene, "after undo")
	assert_eq(scene.get_session().get_state().object_by_id("block_a").position, Vector2i(3, 1))
	scene.request_restart()
	_assert_board_matches_state(scene, "after restart")
	assert_true(scene.get_session().is_at_initial_state())
	scene.free()


func test_hud_reflects_availability() -> void:
	var scene := _spawn()
	var hud := scene.get_hud()
	assert_eq(hud.run_label(), "Run")
	assert_true(hud.is_run_enabled())
	assert_false(hud.is_undo_enabled())
	assert_false(hud.is_restart_enabled())
	scene.request_action(PuzzleAction.run_core())
	assert_eq(hud.run_label(), "Resume")
	assert_true(hud.is_undo_enabled())
	assert_true(hud.is_restart_enabled())
	assert_false(hud.is_run_enabled(), "block A sits on the next route cell")
	scene.free()
