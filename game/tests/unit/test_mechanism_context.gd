extends TestCase
## Which mechanisms are available in each phase (decision D-008).
## Setup allows push only; checkpoint "cp" (3,1) allows gravity only.

const PUSH := MechanismIds.PUSH_PULSE
const GRAVITY := MechanismIds.GRAVITY_SHIFT


## `route_block`: a non-gravity block placed on the route (or none if x < 0).
func _level(route_block: Vector2i, checkpoint_pauses: bool = true) -> LevelDefinition:
	var data := LevelFixtures.corridor()
	LevelFixtures.add_block(data, "p", Vector2i(2, 0))
	LevelFixtures.add_block(data, "z", Vector2i(5, 0))
	if route_block.x >= 0:
		LevelFixtures.add_block(data, "r", route_block, true, false)
	LevelFixtures.add_gravity_zone(data, "g", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])
	data["setup"] = {"allowed_mechanisms": [PUSH]}
	var checkpoint: Dictionary = data["routes"]["main"]["checkpoints"][0]
	checkpoint["allowed_mechanisms"] = [GRAVITY]
	checkpoint["auto_pause"] = checkpoint_pauses
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func test_setup_uses_setup_list() -> void:
	var session := PuzzleSession.new(_level(Vector2i(-1, -1)))
	assert_eq(PuzzleSimulator.allowed_mechanisms(session.get_level(), session.get_state()), PackedStringArray([PUSH]))
	assert_eq(session.apply(PuzzleAction.set_gravity("g", Grid.Direction.DOWN)).failure,
		ActionResult.Failure.MECHANISM_NOT_ALLOWED)
	assert_true(session.apply(PuzzleAction.push("p", Grid.Direction.RIGHT)).is_ok())


func test_checkpoint_uses_checkpoint_list() -> void:
	var session := PuzzleSession.new(_level(Vector2i(-1, -1)))
	session.apply(PuzzleAction.run_core())
	assert_eq(session.get_state().phase, PuzzleState.Phase.CHECKPOINT_PAUSED)
	assert_eq(PuzzleSimulator.allowed_mechanisms(session.get_level(), session.get_state()), PackedStringArray([GRAVITY]))
	assert_eq(session.apply(PuzzleAction.push("p", Grid.Direction.RIGHT)).failure,
		ActionResult.Failure.MECHANISM_NOT_ALLOWED)


func test_blocked_after_checkpoint_uses_that_checkpoint_list() -> void:
	var session := PuzzleSession.new(_level(Vector2i(5, 1)))
	session.apply(PuzzleAction.run_core())
	session.apply(PuzzleAction.run_core())
	assert_eq(session.get_state().phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(PuzzleSimulator.allowed_mechanisms(session.get_level(), session.get_state()), PackedStringArray([GRAVITY]))


func test_blocked_before_any_checkpoint_uses_setup_list() -> void:
	var session := PuzzleSession.new(_level(Vector2i(2, 1)))
	session.apply(PuzzleAction.run_core())
	assert_eq(session.get_state().phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(PuzzleSimulator.allowed_mechanisms(session.get_level(), session.get_state()), PackedStringArray([PUSH]))


func test_non_pausing_checkpoint_does_not_change_context() -> void:
	var session := PuzzleSession.new(_level(Vector2i(5, 1), false))
	session.apply(PuzzleAction.run_core())
	assert_eq(session.get_state().phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(session.get_state().reached_checkpoint_ids, PackedStringArray(["cp"]))
	assert_eq(PuzzleSimulator.allowed_mechanisms(session.get_level(), session.get_state()), PackedStringArray([PUSH]))


func test_nothing_allowed_after_completion() -> void:
	var session := PuzzleSession.new(_level(Vector2i(-1, -1)))
	session.apply(PuzzleAction.run_core())
	session.apply(PuzzleAction.run_core())
	assert_eq(session.get_state().phase, PuzzleState.Phase.LEVEL_COMPLETED)
	assert_eq(PuzzleSimulator.allowed_mechanisms(session.get_level(), session.get_state()), PackedStringArray())
