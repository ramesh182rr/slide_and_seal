class_name SwitchGateResolver
extends RefCounted
## Derived switch and gate state (decisions D-013, D-014). Pressure switches and gates are
## computed from object positions and toggle states every time, so they can never drift.


static func is_switch_on(state: PuzzleState, switch_def: SwitchDefinition) -> bool:
	if switch_def.kind == SwitchDefinition.Kind.TOGGLE:
		return state.toggle_states[switch_def.id]
	var obj := state.object_at(switch_def.position)
	return obj != null and obj.kind == MovableObject.KIND_BLOCK


static func is_gate_open(level: LevelDefinition, state: PuzzleState, gate: GateDefinition) -> bool:
	for switch_id: String in gate.requires:
		if not is_switch_on(state, level.switch_by_id(switch_id)):
			return false
	return true


## A portal carries the core only while all its required switches are on (empty = always).
static func is_portal_active(level: LevelDefinition, state: PuzzleState, portal: PortalDefinition) -> bool:
	for switch_id: String in portal.requires:
		if not is_switch_on(state, level.switch_by_id(switch_id)):
			return false
	return true


## Set of cells currently holding a closed gate.
static func closed_gate_cells(level: LevelDefinition, state: PuzzleState) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for gate: GateDefinition in level.gates:
		if not is_gate_open(level, state, gate):
			cells[gate.position] = true
	return cells


static func is_closed_gate_at(level: LevelDefinition, state: PuzzleState, cell: Vector2i) -> bool:
	var gate := level.gate_at(cell)
	return gate != null and not is_gate_open(level, state, gate)


## Ids of closed gates whose cell holds a block or the core: an invalid state (D-013).
static func occupied_closed_gates(level: LevelDefinition, state: PuzzleState, core_cell: Vector2i) -> PackedStringArray:
	var ids := PackedStringArray()
	for gate: GateDefinition in level.gates:
		if not is_gate_open(level, state, gate) \
				and (state.object_at(gate.position) != null or core_cell == gate.position):
			ids.append(gate.id)
	return ids
