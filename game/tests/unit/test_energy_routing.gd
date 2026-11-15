extends TestCase
## Energy Routing (decisions D-022 – D-025). Fixture: LevelFixtures.energy_corridor().

const ENERGY := MechanismIds.ENERGY_ROUTING
const PUSH := MechanismIds.PUSH_PULSE
const SWITCHES := MechanismIds.SWITCHES_SEALS


func _level(data: Dictionary) -> LevelDefinition:
	var level := LevelFixtures.build(data)
	assert_not_null(level, "fixture must load: %s" % LevelLoader.from_dict(data).errors)
	return level


func _apply(level: LevelDefinition, state: PuzzleState, action: PuzzleAction) -> ActionResult:
	return PuzzleSimulator.apply_action(level, state, action)


func _beam(level: LevelDefinition, state: PuzzleState, emitter_id: String) -> EnergyResolver.Beam:
	for beam: EnergyResolver.Beam in EnergyResolver.trace(level, state):
		if beam.emitter_id == emitter_id:
			return beam
	return null


func _gate_open(level: LevelDefinition, state: PuzzleState, gate_id: String) -> bool:
	for gate: GateDefinition in level.gates:
		if gate.id == gate_id:
			return SwitchGateResolver.is_gate_open(level, state, gate)
	return false


func test_reflection_table() -> void:
	var r := ReflectorDefinition.reflect
	assert_eq(r.call(Grid.Direction.RIGHT, true), Grid.Direction.UP)
	assert_eq(r.call(Grid.Direction.UP, true), Grid.Direction.RIGHT)
	assert_eq(r.call(Grid.Direction.LEFT, true), Grid.Direction.DOWN)
	assert_eq(r.call(Grid.Direction.DOWN, true), Grid.Direction.LEFT)
	assert_eq(r.call(Grid.Direction.RIGHT, false), Grid.Direction.DOWN)
	assert_eq(r.call(Grid.Direction.DOWN, false), Grid.Direction.RIGHT)
	assert_eq(r.call(Grid.Direction.LEFT, false), Grid.Direction.UP)
	assert_eq(r.call(Grid.Direction.UP, false), Grid.Direction.LEFT)


func test_initial_beam_bounces_off_the_board_and_gate_stays_shut() -> void:
	var level := _level(LevelFixtures.energy_corridor())
	var state := level.create_initial_state()
	var beam := _beam(level, state, "e")
	assert_eq(beam.cells, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i])
	assert_eq(beam.receiver_id, "")
	assert_false(_gate_open(level, state, "g"))
	var paused := _apply(level, state, PuzzleAction.run_core()).state
	var blocked := _apply(level, paused, PuzzleAction.run_core())
	assert_eq(blocked.travel.blocked_cell, Vector2i(5, 2), "the unpowered gate stops the core")


func test_flipping_the_mirror_powers_the_receiver_and_opens_the_gate() -> void:
	var level := _level(LevelFixtures.energy_corridor())
	var result := _apply(level, level.create_initial_state(), PuzzleAction.flip_reflector("m"))
	assert_true(result.is_ok(), result.message)
	assert_false(result.state.reflector_slash["m"])
	assert_eq(result.state.mechanism_action_count, 1)
	var beam := _beam(level, result.state, "e")
	assert_eq(beam.cells,
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)] as Array[Vector2i],
		"the beam crosses the core's corridor without affecting it")
	assert_eq(beam.receiver_id, "r")
	assert_true(result.state.powered_receivers.has("r"))
	assert_true(_gate_open(level, result.state, "g"))
	var paused := _apply(level, result.state, PuzzleAction.run_core()).state
	assert_eq(_apply(level, paused, PuzzleAction.run_core()).state.phase, PuzzleState.Phase.LEVEL_COMPLETED)


func test_block_stops_the_beam() -> void:
	var level := _level(LevelFixtures.add_block(LevelFixtures.energy_corridor(), "k", Vector2i(3, 1)))
	var state := _apply(level, level.create_initial_state(), PuzzleAction.flip_reflector("m")).state
	assert_eq(_beam(level, state, "e").cells.back(), Vector2i(3, 0))
	assert_false(state.powered_receivers.has("r"))


func test_closed_gate_stops_the_beam() -> void:
	var data := LevelFixtures.add_switch(LevelFixtures.energy_corridor(), "t", "toggle", Vector2i(0, 4))
	LevelFixtures.add_gate(data, "g2", Vector2i(3, 1), ["t"])
	var level := _level(LevelFixtures.allow_everywhere(data, [ENERGY, SWITCHES]))
	var flipped := _apply(level, level.create_initial_state(), PuzzleAction.flip_reflector("m")).state
	assert_false(flipped.powered_receivers.has("r"), "closed gate g2 is in the way")
	var opened := _apply(level, flipped, PuzzleAction.toggle_switch("t")).state
	assert_true(opened.powered_receivers.has("r"))


func test_switch_controlled_emitter() -> void:
	var data := LevelFixtures.energy_corridor()
	data["mechanisms"]["energy_emitters"][0]["requires"] = ["t"]
	LevelFixtures.add_switch(data, "t", "toggle", Vector2i(0, 4))
	data["mechanisms"]["reflectors"][0]["orientation"] = "\\"
	var level := _level(LevelFixtures.allow_everywhere(data, [ENERGY, SWITCHES]))
	var state := level.create_initial_state()
	assert_null(_beam(level, state, "e"), "no beam while the switch is off")
	var on := _apply(level, state, PuzzleAction.toggle_switch("t")).state
	assert_true(on.powered_receivers.has("r"))


func test_power_chains_through_gates_and_emitters() -> void:
	# e lights r; r opens gate g2 on e2's path and also powers emitter e3; both e2 and e3 reach receivers.
	var data := LevelFixtures.energy_corridor()
	data["mechanisms"]["reflectors"][0]["orientation"] = "\\"
	LevelFixtures.add_gate(data, "g2", Vector2i(5, 3), ["r"])
	LevelFixtures.add_emitter(data, "e2", Vector2i(5, 4), "up")
	LevelFixtures.add_switch(data, "r2", "receiver", Vector2i(5, 1))
	LevelFixtures.add_emitter(data, "e3", Vector2i(6, 3), "up", ["r"])
	LevelFixtures.add_switch(data, "r3", "receiver", Vector2i(6, 1))
	data["routes"]["main"]["nodes"] = [[0, 2], [1, 2], [2, 2]]
	data["destination"]["position"] = [2, 2]
	data["mechanisms"]["gates"] = [{"id": "g2", "position": [5, 3], "requires": ["r"]}]
	var level := _level(data)
	var state := level.create_initial_state()
	assert_true(state.powered_receivers.has("r"))
	assert_true(state.powered_receivers.has("r2"), "e2's beam passes the gate that r opened")
	assert_true(state.powered_receivers.has("r3"), "e3 runs because r is powered")


func test_emitters_and_reflectors_are_solid_for_blocks() -> void:
	var data := LevelFixtures.add_block(LevelFixtures.energy_corridor(), "k", Vector2i(4, 0))
	var level := _level(LevelFixtures.allow_everywhere(data, [ENERGY, PUSH]))
	assert_eq(_apply(level, level.create_initial_state(), PuzzleAction.push("k", Grid.Direction.LEFT)).failure,
		ActionResult.Failure.MOVE_BLOCKED, "the mirror cell is solid")


func test_gate_never_closes_on_the_core_when_the_beam_is_cut() -> void:
	# Checkpoint on the gate cell: the core rests on the open gate; pushing a block into the beam
	# would unpower it and close it on the core, so the push is refused (D-013).
	var data := LevelFixtures.add_block(LevelFixtures.energy_corridor(), "k", Vector2i(4, 1))
	data["routes"]["main"]["checkpoints"][0]["position"] = [5, 2]
	var level := _level(LevelFixtures.allow_everywhere(data, [ENERGY, PUSH]))
	var state := _apply(level, level.create_initial_state(), PuzzleAction.flip_reflector("m")).state
	state = _apply(level, state, PuzzleAction.run_core()).state
	assert_eq(PuzzleSimulator.core_position(level, state), Vector2i(5, 2))
	assert_eq(_apply(level, state, PuzzleAction.push("k", Grid.Direction.LEFT)).failure,
		ActionResult.Failure.GATE_OCCUPIED)


func test_flip_rejections() -> void:
	var level := _level(LevelFixtures.energy_corridor())
	assert_eq(_apply(level, level.create_initial_state(), PuzzleAction.flip_reflector("nope")).failure,
		ActionResult.Failure.INVALID_TARGET)
	var locked := LevelFixtures.energy_corridor()
	LevelFixtures.allow_everywhere(locked, [])
	var locked_level := _level(locked)
	assert_eq(_apply(locked_level, locked_level.create_initial_state(), PuzzleAction.flip_reflector("m")).failure,
		ActionResult.Failure.MECHANISM_NOT_ALLOWED)


func test_undo_preview_and_key() -> void:
	var level := _level(LevelFixtures.energy_corridor())
	var session := PuzzleSession.new(level)
	var before := session.get_state().to_key()
	var preview := session.preview(PuzzleAction.flip_reflector("m"))
	assert_eq(session.get_state().to_key(), before, "preview must not commit")
	session.apply(PuzzleAction.flip_reflector("m"))
	assert_eq(session.get_state().to_key(), preview.state.to_key())
	assert_ne(session.get_state().to_key(false), before, "mirror orientation is part of the key")
	assert_true(session.undo())
	assert_eq(session.get_state().to_key(), before)
	assert_false(session.get_state().powered_receivers.has("r"), "power is restored with the state")


func test_solver_finds_single_flip() -> void:
	var result := PuzzleSolver.solve(_level(LevelFixtures.energy_corridor()))
	assert_true(result.solvable)
	assert_eq(result.minimum_actions, 1)


# --- Loader ------------------------------------------------------------------------

func _assert_rejected(data: Dictionary, fragment: String) -> void:
	var result := LevelLoader.from_dict(data)
	assert_null(result.level, "level should be rejected")
	var found := false
	for message: String in result.errors:
		found = found or message.contains(fragment)
	assert_true(found, "expected an error containing '%s', got %s" % [fragment, result.errors])


func test_rejects_bad_orientation() -> void:
	var data := LevelFixtures.energy_corridor()
	data["mechanisms"]["reflectors"][0]["orientation"] = "|"
	_assert_rejected(data, "orientation must be")


func test_rejects_emitter_on_route() -> void:
	_assert_rejected(LevelFixtures.add_emitter(LevelFixtures.energy_corridor(), "e2", Vector2i(2, 2), "up"),
		"emitter 'e2' at (2, 2) must not be on a route")


func test_rejects_reflector_sharing_a_switch_cell() -> void:
	_assert_rejected(LevelFixtures.add_reflector(LevelFixtures.energy_corridor(), "m2", Vector2i(3, 3), "/"),
		"reflector 'm2' shares a cell with switch 'r'")


func test_rejects_emitter_requiring_unknown_switch() -> void:
	var data := LevelFixtures.energy_corridor()
	data["mechanisms"]["energy_emitters"][0]["requires"] = ["ghost"]
	_assert_rejected(data, "emitter 'e' requires unknown switch 'ghost'")


func test_rejects_block_inside_a_fixture() -> void:
	_assert_rejected(LevelFixtures.add_block(LevelFixtures.energy_corridor(), "k", Vector2i(3, 0)),
		"object 'k' starts inside a solid fixture")


func test_rejects_receivers_collection() -> void:
	var data := LevelFixtures.energy_corridor()
	data["mechanisms"]["receivers"] = [{"id": "x"}]
	_assert_rejected(data, "declare receivers in mechanisms.switches with kind 'receiver'")


func test_rejects_energy_allowed_without_reflectors() -> void:
	var data := LevelFixtures.energy_corridor()
	data["mechanisms"]["reflectors"] = []
	_assert_rejected(data, "allows energy_routing but the level has no reflectors")


func test_receiver_kind_loads_and_cannot_be_toggled() -> void:
	var level := _level(LevelFixtures.energy_corridor())
	assert_eq(level.switch_by_id("r").kind, SwitchDefinition.Kind.RECEIVER)
	var data := LevelFixtures.energy_corridor()
	LevelFixtures.allow_everywhere(data, [ENERGY, SWITCHES])
	_assert_rejected(data, "allows switches_seals but the level has no toggle switches")
