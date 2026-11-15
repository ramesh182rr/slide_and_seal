extends TestCase
## Switches & Seals (decisions D-013, D-014). Base fixture: 7x3 corridor, route along y = 1,
## checkpoint "cp" at (3,1), core starts at (0,1).

const PUSH := MechanismIds.PUSH_PULSE
const GRAVITY := MechanismIds.GRAVITY_SHIFT
const SWITCHES := MechanismIds.SWITCHES_SEALS
const UP := Grid.Direction.UP
const DOWN := Grid.Direction.DOWN
const RIGHT := Grid.Direction.RIGHT
const LEFT := Grid.Direction.LEFT


func _level(data: Dictionary) -> LevelDefinition:
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


## Gate "g" on the route at (5,1) behind toggle switch "t" at (5,0); switches allowed everywhere.
func _toggle_gate_level(initially_on: bool = false) -> LevelDefinition:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(5, 0), initially_on)
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["t"])
	return _level(LevelFixtures.allow_everywhere(data, [SWITCHES]))


## Gate "g" at (5,1) behind pressure switch "p" at (2,2); block "b" pushable everywhere.
func _pressure_gate_level(block: Vector2i) -> LevelDefinition:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "p", "pressure", Vector2i(2, 2))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["p"])
	LevelFixtures.add_block(data, "b", block)
	return _level(LevelFixtures.allow_everywhere(data, [PUSH]))


# --- Gate blocking --------------------------------------------------------------

func test_closed_gate_blocks_the_core() -> void:
	var level := _toggle_gate_level()
	var session := PuzzleSession.new(level)
	session.apply(PuzzleAction.run_core())
	var result := session.apply(PuzzleAction.run_core())
	assert_eq(result.state.phase, PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION)
	assert_eq(result.travel.blocked_cell, Vector2i(5, 1))


func test_open_gate_lets_the_core_pass() -> void:
	var level := _toggle_gate_level(true)
	var session := PuzzleSession.new(level)
	session.apply(PuzzleAction.run_core())
	assert_eq(session.apply(PuzzleAction.run_core()).state.phase, PuzzleState.Phase.LEVEL_COMPLETED)


func test_closed_gate_blocks_pushes() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(0, 2))
	LevelFixtures.add_gate(data, "g", Vector2i(3, 0), ["t"])
	LevelFixtures.add_block(data, "b", Vector2i(2, 0))
	var level := _level(LevelFixtures.allow_everywhere(data, [PUSH, SWITCHES]))
	var state := level.create_initial_state()
	assert_eq(PuzzleSimulator.apply_action(level, state, PuzzleAction.push("b", RIGHT)).failure,
		ActionResult.Failure.MOVE_BLOCKED)
	var opened := PuzzleSimulator.apply_action(level, state, PuzzleAction.toggle_switch("t")).state
	assert_true(PuzzleSimulator.apply_action(level, opened, PuzzleAction.push("b", RIGHT)).is_ok(),
		"an open gate is ordinary floor")


func test_closed_gate_stops_gravity() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(0, 2))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["t"])
	LevelFixtures.add_block(data, "b", Vector2i(5, 0))
	LevelFixtures.add_gravity_zone(data, "z", Vector2i(5, 0), Vector2i(1, 3), "up", ["up", "down"])
	var level := _level(LevelFixtures.allow_everywhere(data, [GRAVITY, SWITCHES]))
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.set_gravity("z", DOWN))
	assert_eq(result.state.object_by_id("b").position, Vector2i(5, 0), "the closed gate below holds the block")


# --- Toggle switches ------------------------------------------------------------

func test_toggle_flips_state_and_counts_an_action() -> void:
	var level := _toggle_gate_level()
	var gate := level.gate_at(Vector2i(5, 1))
	var state := level.create_initial_state()
	assert_false(SwitchGateResolver.is_gate_open(level, state, gate))
	var result := PuzzleSimulator.apply_action(level, state, PuzzleAction.toggle_switch("t"))
	assert_true(result.is_ok(), result.message)
	assert_true(result.state.toggle_states["t"])
	assert_true(SwitchGateResolver.is_gate_open(level, result.state, gate))
	assert_eq(result.state.mechanism_action_count, 1)
	var back := PuzzleSimulator.apply_action(level, result.state, PuzzleAction.toggle_switch("t"))
	assert_false(SwitchGateResolver.is_gate_open(level, back.state, gate), "toggling again closes it")


func test_toggle_rejected_for_unknown_or_pressure_switch() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(5, 0))
	LevelFixtures.add_switch(data, "p", "pressure", Vector2i(4, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["t", "p"])
	var level := _level(LevelFixtures.allow_everywhere(data, [SWITCHES]))
	var state := level.create_initial_state()
	assert_eq(PuzzleSimulator.apply_action(level, state, PuzzleAction.toggle_switch("p")).failure,
		ActionResult.Failure.INVALID_TARGET, "pressure switches cannot be toggled")
	assert_eq(PuzzleSimulator.apply_action(level, state, PuzzleAction.toggle_switch("nope")).failure,
		ActionResult.Failure.INVALID_TARGET)


func test_toggle_requires_switches_mechanism() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(5, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["t"])
	var level := _level(data)
	assert_eq(PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.toggle_switch("t")).failure,
		ActionResult.Failure.MECHANISM_NOT_ALLOWED)


# --- Pressure switches ----------------------------------------------------------

func test_block_on_pressure_switch_opens_gate() -> void:
	var level := _pressure_gate_level(Vector2i(1, 2))
	var gate := level.gate_at(Vector2i(5, 1))
	var state := level.create_initial_state()
	assert_false(SwitchGateResolver.is_gate_open(level, state, gate))
	var pushed := PuzzleSimulator.apply_action(level, state, PuzzleAction.push("b", RIGHT)).state
	assert_true(SwitchGateResolver.is_gate_open(level, pushed, gate))
	var off := PuzzleSimulator.apply_action(level, pushed, PuzzleAction.push("b", RIGHT)).state
	assert_false(SwitchGateResolver.is_gate_open(level, off, gate), "pressure switches are only on while pressed")


func test_core_does_not_press_switches() -> void:
	# Pressure switch on the route at (2,1); the core paused on it must not open the gate.
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "p", "pressure", Vector2i(3, 1))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["p"])
	var level := _level(data)
	var paused := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.run_core()).state
	assert_eq(PuzzleSimulator.core_position(level, paused), Vector2i(3, 1))
	assert_false(SwitchGateResolver.is_gate_open(level, paused, level.gate_at(Vector2i(5, 1))))


func test_gate_requires_all_switches() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t1", "toggle", Vector2i(4, 0))
	LevelFixtures.add_switch(data, "t2", "toggle", Vector2i(6, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["t1", "t2"])
	var level := _level(LevelFixtures.allow_everywhere(data, [SWITCHES]))
	var gate := level.gate_at(Vector2i(5, 1))
	var one := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.toggle_switch("t1")).state
	assert_false(SwitchGateResolver.is_gate_open(level, one, gate))
	var both := PuzzleSimulator.apply_action(level, one, PuzzleAction.toggle_switch("t2")).state
	assert_true(SwitchGateResolver.is_gate_open(level, both, gate))


# --- D-013: never close an occupied gate ------------------------------------------

func test_rejects_closing_gate_on_a_block() -> void:
	# Block "b" holds pressure switch "p" (gate open); block "c" sits in the open gate.
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "p", "pressure", Vector2i(2, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(4, 2), ["p"])
	LevelFixtures.add_block(data, "b", Vector2i(2, 0))
	LevelFixtures.add_block(data, "c", Vector2i(4, 2))
	var level := _level(LevelFixtures.allow_everywhere(data, [PUSH]))
	var state := level.create_initial_state()
	var key := state.to_key()
	var result := PuzzleSimulator.apply_action(level, state, PuzzleAction.push("b", RIGHT))
	assert_eq(result.failure, ActionResult.Failure.GATE_OCCUPIED)
	assert_eq(state.to_key(), key)
	assert_true(PuzzleSimulator.apply_action(level, state, PuzzleAction.push("c", RIGHT)).is_ok(),
		"moving the block out of the gate is fine")


func test_rejects_closing_gate_on_the_core() -> void:
	# The core pauses on the open gate cell (3,1) (also the checkpoint); toggling it shut is refused.
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "t", "toggle", Vector2i(3, 0), true)
	LevelFixtures.add_gate(data, "g", Vector2i(3, 1), ["t"])
	var level := _level(LevelFixtures.allow_everywhere(data, [SWITCHES]))
	var paused := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.run_core()).state
	assert_eq(PuzzleSimulator.core_position(level, paused), Vector2i(3, 1))
	assert_eq(PuzzleSimulator.apply_action(level, paused, PuzzleAction.toggle_switch("t")).failure,
		ActionResult.Failure.GATE_OCCUPIED)


func test_rejects_run_when_travel_would_close_occupied_gate() -> void:
	# Gravity column x=0 pointing down: block "b" rests on the core at (0,1) and on nothing else.
	# Pressure switch at (0,0) is held by "b"; it keeps gate (4,0) open for block "c" standing in it.
	# When the core leaves (0,1), "b" falls off the switch and the gate would close on "c".
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "p", "pressure", Vector2i(0, 0))
	LevelFixtures.add_gate(data, "g", Vector2i(4, 0), ["p"])
	LevelFixtures.add_block(data, "b", Vector2i(0, 0))
	LevelFixtures.add_block(data, "c", Vector2i(4, 0))
	LevelFixtures.add_gravity_zone(data, "z", Vector2i(0, 0), Vector2i(1, 3), "down", ["down"])
	var level := _level(data)
	var state := level.create_initial_state()
	var key := state.to_key()
	var result := PuzzleSimulator.apply_action(level, state, PuzzleAction.run_core())
	assert_eq(result.failure, ActionResult.Failure.GATE_OCCUPIED)
	assert_eq(state.to_key(), key)


# --- Stabilization ----------------------------------------------------------------

func test_opening_gate_lets_gravity_continue() -> void:
	# Column zone x=5 pointing down holds block "b" above a closed gate at (5,1).
	# Pushing "p" onto pressure switch (2,2) opens the gate; "b" must then fall through to (5,2).
	var data := LevelFixtures.add_switch(LevelFixtures.corridor(), "s", "pressure", Vector2i(2, 2))
	LevelFixtures.add_gate(data, "g", Vector2i(5, 1), ["s"])
	LevelFixtures.add_block(data, "b", Vector2i(5, 0))
	LevelFixtures.add_block(data, "p", Vector2i(1, 2))
	LevelFixtures.add_gravity_zone(data, "z", Vector2i(5, 0), Vector2i(1, 3), "down", ["down"])
	var level := _level(LevelFixtures.allow_everywhere(data, [PUSH]))
	var result := PuzzleSimulator.apply_action(level, level.create_initial_state(), PuzzleAction.push("p", RIGHT))
	assert_true(result.is_ok(), result.message)
	assert_eq(result.state.object_by_id("b").position, Vector2i(5, 2))
	assert_eq(result.object_moves.size(), 2, "the push, then one merged gravity move")
	assert_eq(result.object_moves[1].from_cell, Vector2i(5, 0))


func test_toggle_state_is_restored_by_undo() -> void:
	var session := PuzzleSession.new(_toggle_gate_level())
	var before := session.get_state().to_key()
	assert_true(session.apply(PuzzleAction.toggle_switch("t")).is_ok())
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), before)


func test_preview_matches_apply() -> void:
	var level := _pressure_gate_level(Vector2i(1, 2))
	var state := level.create_initial_state()
	var key := state.to_key()
	var action := PuzzleAction.push("b", RIGHT)
	var preview := PuzzleSimulator.preview_action(level, state, action)
	assert_eq(state.to_key(), key)
	assert_eq(preview.state.to_key(), PuzzleSimulator.apply_action(level, state, action).state.to_key())


func test_solver_uses_toggles() -> void:
	var result := PuzzleSolver.solve(_toggle_gate_level())
	assert_true(result.solvable)
	assert_eq(result.minimum_actions, 1)
