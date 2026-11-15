class_name MechanismFixtures3D
extends Node3D
## Placeholder visuals for switches, gates and portals, plus the link symbols that make their
## dependencies readable without colour alone (docs/05 §4): gates get letters (A, B, …), entry/exit
## portal pairs get numbers (1, 2, …), and every switch shows the symbols of everything it powers.
## Read-only with respect to the simulation; state comes from SwitchGateResolver.

const GATE_HEIGHT := 0.72
const LABEL_HEIGHT := 1.15

var _level: LevelDefinition
var _library: MaterialLibrary
var _symbols: Dictionary[String, String] = {}
var _gates: Dictionary[String, MeshInstance3D] = {}
var _switch_lamps: Dictionary[String, MeshInstance3D] = {}
var _switch_bases: Dictionary[String, MeshInstance3D] = {}
var _portal_rings: Dictionary[String, MeshInstance3D] = {}
var _labels: Dictionary[String, Label3D] = {}
var _lit: Dictionary[String, bool] = {}


func build(level: LevelDefinition, library: MaterialLibrary) -> void:
	_level = level
	_library = library
	_symbols = compute_symbols(level)
	for switch_def: SwitchDefinition in level.switches:
		_build_switch(switch_def)
	for gate: GateDefinition in level.gates:
		_build_gate(gate)
	for portal: PortalDefinition in level.portals:
		_build_portal(portal)


func sync_to_state(state: PuzzleState) -> void:
	for switch_def: SwitchDefinition in _level.switches:
		var on := SwitchGateResolver.is_switch_on(state, switch_def)
		_lit[switch_def.id] = on
		_switch_lamps[switch_def.id].material_override = _lamp_material(on)
	for gate: GateDefinition in _level.gates:
		var node := _gates[gate.id]
		node.position.y = gate_y(SwitchGateResolver.is_gate_open(_level, state, gate))
	for portal: PortalDefinition in _level.portals:
		var active := _portal_active(state, portal)
		_lit[portal.id] = active
		_portal_rings[portal.id].material_override = _portal_material(active)


## Ghosts for gates a preview would change: a raised ghost where an open gate would close, and a
## glowing shell around a closed gate that would open (anything at floor level would be hidden by it).
func add_preview_ghosts(parent: Node3D, current: PuzzleState, previewed: PuzzleState) -> void:
	var closing := BoxMesh.new()
	closing.size = Vector3(0.86, GATE_HEIGHT, 0.86)
	var opening := BoxMesh.new()
	opening.size = Vector3(0.98, GATE_HEIGHT + 0.12, 0.98)
	for gate: GateDefinition in _level.gates:
		var open_after := SwitchGateResolver.is_gate_open(_level, previewed, gate)
		if open_after != SwitchGateResolver.is_gate_open(_level, current, gate):
			var instance := MeshInstance3D.new()
			instance.mesh = opening if open_after else closing
			instance.material_override = _library.get_material("ghost", Palette.CYAN_ENERGY, 0.8, 0.35)
			instance.position = BoardCoords.cell_to_world(gate.position, gate_y(false))
			parent.add_child(instance)


func gate_node(gate_id: String) -> MeshInstance3D:
	return _gates.get(gate_id)


func switch_base(switch_id: String) -> MeshInstance3D:
	return _switch_bases.get(switch_id)


func is_lit(fixture_id: String) -> bool:
	return _lit.get(fixture_id, false)


func symbol(fixture_id: String) -> String:
	return _symbols.get(fixture_id, "")


func label_text(fixture_id: String) -> String:
	return _labels[fixture_id].text if _labels.has(fixture_id) else ""


## Closed gates stand on the cell; open gates sink so only a sliver shows above the floor.
static func gate_y(open: bool) -> float:
	return -GATE_HEIGHT * 0.5 + 0.04 if open else GATE_HEIGHT * 0.5 - 0.02


## Gates → "A", "B", … (by id); entry portals → "1", "2", … shared with their exit;
## switches → the sorted symbols of every gate and portal that requires them.
static func compute_symbols(level: LevelDefinition) -> Dictionary[String, String]:
	var symbols: Dictionary[String, String] = {}
	for i: int in level.gates.size():
		symbols[level.gates[i].id] = String.chr("A".unicode_at(0) + i)
	var number := 1
	for portal: PortalDefinition in level.portals:
		if portal.exit_id != "":
			symbols[portal.id] = str(number)
			symbols[portal.exit_id] = str(number)
			number += 1
	for switch_def: SwitchDefinition in level.switches:
		var powered := PackedStringArray()
		for gate: GateDefinition in level.gates:
			if gate.requires.has(switch_def.id):
				powered.append(symbols[gate.id])
		for portal: PortalDefinition in level.portals:
			if portal.requires.has(switch_def.id):
				powered.append(symbols[portal.id])
		powered.sort()
		symbols[switch_def.id] = " ".join(powered)
	return symbols


func _build_switch(switch_def: SwitchDefinition) -> void:
	var at := BoardCoords.cell_to_world(switch_def.position)
	if switch_def.kind == SwitchDefinition.Kind.PRESSURE:
		# A square plate that lights up while pressed: the plate is its own lamp.
		var plate := BoxMesh.new()
		plate.size = Vector3(0.72, 0.05, 0.72)
		var lamp := _mesh(plate, at + Vector3(0, 0.025, 0))
		_switch_lamps[switch_def.id] = lamp
		_switch_bases[switch_def.id] = lamp
	else:
		# A round lever base with a lamp on top.
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 0.32
		base_mesh.bottom_radius = 0.36
		base_mesh.height = 0.12
		var base := _mesh(base_mesh, at + Vector3(0, 0.06, 0))
		base.material_override = _library.get_material("lever_base", Palette.WALL.lightened(0.25), 0.0, 1.0, 0.5, 0.4)
		var knob := CylinderMesh.new()
		knob.top_radius = 0.14
		knob.bottom_radius = 0.14
		knob.height = 0.3
		_switch_lamps[switch_def.id] = _mesh(knob, at + Vector3(0, 0.27, 0))
		_switch_bases[switch_def.id] = base
	_label(switch_def.id, at + Vector3(0, 0.7, 0), Palette.TEXT)


func _build_gate(gate: GateDefinition) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.86, GATE_HEIGHT, 0.86)
	var node := _mesh(box, BoardCoords.cell_to_world(gate.position))
	node.material_override = _library.get_material("gate", Palette.MECHANISM_AMBER, 0.35, 1.0, 0.6, 0.35)
	node.name = "Gate_%s" % gate.id
	_gates[gate.id] = node
	_label(gate.id, BoardCoords.cell_to_world(gate.position, LABEL_HEIGHT), Palette.MECHANISM_AMBER)


func _build_portal(portal: PortalDefinition) -> void:
	var at := BoardCoords.cell_to_world(portal.position)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.44
	_portal_rings[portal.id] = _mesh(ring, at + Vector3(0, 0.05, 0))
	if portal.exit_id != "":
		# Entry portals get a swirl disc so entry and exit read differently.
		var disc := CylinderMesh.new()
		disc.top_radius = 0.26
		disc.bottom_radius = 0.26
		disc.height = 0.02
		var swirl := _mesh(disc, at + Vector3(0, 0.03, 0))
		swirl.material_override = _library.get_material("portal_disc", Palette.PORTAL_VIOLET, 0.8, 0.45)
	_label(portal.id, at + Vector3(0, 0.7, 0), Palette.PORTAL_VIOLET)


func _portal_active(state: PuzzleState, portal: PortalDefinition) -> bool:
	if portal.exit_id != "":
		return SwitchGateResolver.is_portal_active(_level, state, portal)
	# An exit is lit when any entry leading to it is active.
	for other: PortalDefinition in _level.portals:
		if other.exit_id == portal.id and SwitchGateResolver.is_portal_active(_level, state, other):
			return true
	return false


func _lamp_material(on: bool) -> StandardMaterial3D:
	return _library.get_material("lamp_on", Palette.MINT_SUCCESS, 1.6) if on \
		else _library.get_material("lamp_off", Palette.MECHANISM_AMBER.darkened(0.45), 0.2)


func _portal_material(active: bool) -> StandardMaterial3D:
	return _library.get_material("portal_on", Palette.PORTAL_VIOLET, 1.8) if active \
		else _library.get_material("portal_off", Palette.PORTAL_VIOLET.darkened(0.6), 0.15)


func _label(fixture_id: String, at: Vector3, color: Color) -> void:
	var text := symbol(fixture_id)
	if text == "":
		return
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 72
	label.pixel_size = 0.005
	label.outline_size = 14
	label.modulate = color
	add_child(label)
	_labels[fixture_id] = label


func _mesh(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance
