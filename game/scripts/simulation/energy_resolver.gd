class_name EnergyResolver
extends RefCounted
## Energy beams (decisions D-022 – D-025). Beams are traced on the grid from every active emitter;
## receivers hit by a beam are powered. Power is stored in PuzzleState.powered_receivers but always
## recomputed from the rest of the state by update_power(), so it never drifts.

const MAX_BEAM_STEPS := 4096


class Beam:
	extends RefCounted
	var emitter_id: String = ""
	## Cells the beam passes through, in order (emitter cell excluded; reflector cells included).
	var cells: Array[Vector2i] = []
	## Receiver that absorbed the beam, or "".
	var receiver_id: String = ""


## Recomputes powered receivers. Starting from "nothing powered", repeat: trace beams with the
## current power (which opens gates and activates emitters), collect lit receivers. More power can
## only open gates or start emitters, which only extends beams, so this reaches a fixed point.
static func update_power(level: LevelDefinition, state: PuzzleState) -> void:
	if level.emitters.is_empty():
		return
	state.powered_receivers.clear()
	for pass_index: int in level.switches.size() + 2:
		var lit: Dictionary[String, bool] = {}
		for beam: Beam in trace(level, state):
			if beam.receiver_id != "":
				lit[beam.receiver_id] = true
		if lit.size() == state.powered_receivers.size():
			return
		state.powered_receivers = lit


## Traces every active emitter's beam with the state's current gates and power.
static func trace(level: LevelDefinition, state: PuzzleState) -> Array[Beam]:
	var beams: Array[Beam] = []
	for emitter: EmitterDefinition in level.emitters:
		if is_emitter_active(state, emitter, level):
			beams.append(_trace_one(level, state, emitter))
	return beams


static func is_emitter_active(state: PuzzleState, emitter: EmitterDefinition, level: LevelDefinition) -> bool:
	for switch_id: String in emitter.requires:
		if not SwitchGateResolver.is_switch_on(state, level.switch_by_id(switch_id)):
			return false
	return true


static func _trace_one(level: LevelDefinition, state: PuzzleState, emitter: EmitterDefinition) -> Beam:
	var beam := Beam.new()
	beam.emitter_id = emitter.id
	var cell := emitter.position
	var direction := emitter.direction
	var visited: Dictionary[String, bool] = {}
	for step: int in MAX_BEAM_STEPS:
		cell += Grid.offset(direction)
		if not level.in_bounds(cell) or PuzzleSimulator.is_terrain_wall_at(level, state, cell) \
				or level.emitter_at(cell) != null or state.object_at(cell) != null \
				or SwitchGateResolver.is_closed_gate_at(level, state, cell):
			return beam
		var key := "%d,%d,%d" % [cell.x, cell.y, direction]
		if visited.has(key):
			return beam  # A loop: stop rather than hang (docs/03 §6).
		visited[key] = true
		beam.cells.append(cell)
		var receiver := level.receiver_at(cell)
		if receiver != null:
			beam.receiver_id = receiver.id
			return beam
		var reflector := level.reflector_at(cell)
		if reflector != null:
			direction = ReflectorDefinition.reflect(direction, state.reflector_slash[reflector.id])
	return beam
