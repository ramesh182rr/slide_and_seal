class_name MechanismFixtures3D
extends Node3D
## Visuals for switches, gates and portals (M11 art pass), plus the link symbols that make their
## dependencies readable without colour alone (docs/05 §4): gates get letters (A, B, …), entry/exit
## portal pairs get numbers (1, 2, …), and every switch shows the symbols of everything it powers.
## Read-only with respect to the simulation; state comes from SwitchGateResolver.

const GATE_HEIGHT := 0.72
const LABEL_HEIGHT := 1.15
const BEAM_HEIGHT := 0.36
const BEAM_THICKNESS := 0.07
const LEVER_TILT := 0.5

var _level: LevelDefinition
var _library: MaterialLibrary
var _pieces: PieceKit
var _symbols: Dictionary[String, String] = {}
var _gates: Dictionary[String, MeshInstance3D] = {}
var _switch_lamps: Dictionary[String, MeshInstance3D] = {}
var _switch_bases: Dictionary[String, MeshInstance3D] = {}
## Toggle levers: the arm pivot tilts one way when on, the other when off.
var _lever_arms: Dictionary[String, Node3D] = {}
var _portal_rings: Dictionary[String, MeshInstance3D] = {}
var _labels: Dictionary[String, Label3D] = {}
var _lit: Dictionary[String, bool] = {}
var _reflector_pivots: Dictionary[String, Node3D] = {}
var _magnet_caps: Dictionary[String, MeshInstance3D] = {}
var _magnet_labels: Dictionary[String, Label3D] = {}
var _beam_root: Node3D


func build(level: LevelDefinition, library: MaterialLibrary, pieces: PieceKit = null) -> void:
	_level = level
	_library = library
	_pieces = pieces if pieces != null else PieceKit.new(library, WorldTheme.for_world(level.world_id))
	_symbols = compute_symbols(level)
	for switch_def: SwitchDefinition in level.switches:
		_build_switch(switch_def)
	for gate: GateDefinition in level.gates:
		_build_gate(gate)
	for portal: PortalDefinition in level.portals:
		_build_portal(portal)
	for emitter: EmitterDefinition in level.emitters:
		_build_emitter(emitter)
	for reflector: ReflectorDefinition in level.reflectors:
		_build_reflector(reflector)
	for magnet: MagnetDefinition in level.magnets:
		_build_magnet(magnet)
	_beam_root = Node3D.new()
	_beam_root.name = "Beams"
	add_child(_beam_root)


func sync_to_state(state: PuzzleState) -> void:
	for switch_def: SwitchDefinition in _level.switches:
		var on := SwitchGateResolver.is_switch_on(state, switch_def)
		_lit[switch_def.id] = on
		_switch_lamps[switch_def.id].material_override = _lamp_material(on)
		if _lever_arms.has(switch_def.id):
			_lever_arms[switch_def.id].rotation.z = -LEVER_TILT if on else LEVER_TILT
	for gate: GateDefinition in _level.gates:
		var node := _gates[gate.id]
		node.position.y = gate_y(SwitchGateResolver.is_gate_open(_level, state, gate))
	for portal: PortalDefinition in _level.portals:
		var active := _portal_active(state, portal)
		_lit[portal.id] = active
		_portal_rings[portal.id].material_override = _portal_material(active)
	for reflector: ReflectorDefinition in _level.reflectors:
		_reflector_pivots[reflector.id].rotation.y = reflector_yaw(state.reflector_slash[reflector.id])
	for magnet: MagnetDefinition in _level.magnets:
		var positive: bool = state.magnet_positive[magnet.id]
		_magnet_caps[magnet.id].material_override = polarity_material(_library, positive)
		_magnet_labels[magnet.id].text = polarity_symbol(positive)
		_magnet_labels[magnet.id].modulate = polarity_color(positive)
	for child: Node in _beam_root.get_children():
		_beam_root.remove_child(child)
		child.free()
	add_beams(_beam_root, state, false)


## Draws every beam the state's simulation traces. Ghost beams (previews) are translucent mint.
func add_beams(parent: Node3D, state: PuzzleState, ghost: bool) -> void:
	var material := _library.get_material("beam_ghost", Palette.MINT_SUCCESS, 1.2, 0.45) if ghost \
		else _library.get_material("beam", Palette.CYAN_ENERGY, 3.0)
	for beam: EnergyResolver.Beam in EnergyResolver.trace(_level, state):
		var emitter := _emitter(beam.emitter_id)
		var points: Array[Vector3] = [BoardCoords.cell_to_world(emitter.position, BEAM_HEIGHT)]
		for cell: Vector2i in beam.cells:
			points.append(BoardCoords.cell_to_world(cell, BEAM_HEIGHT))
		if beam.receiver_id == "":
			# Show the beam reaching the face of whatever stopped it.
			var last_direction := Grid.offset(emitter.direction)
			if beam.cells.size() >= 1:
				var reflector := _level.reflector_at(beam.cells.back())
				var before := emitter.position if beam.cells.size() == 1 else beam.cells[beam.cells.size() - 2]
				last_direction = beam.cells.back() - before
				if reflector != null:
					last_direction = Grid.offset(ReflectorDefinition.reflect(
						_direction_of(last_direction), state.reflector_slash[reflector.id]))
			points.append(points.back() + Vector3(last_direction.x, 0, last_direction.y) * 0.5)
		for i: int in range(1, points.size()):
			var a := points[i - 1]
			var b := points[i]
			var segment := BoxMesh.new()
			var length := a.distance_to(b)
			segment.size = Vector3(length, BEAM_THICKNESS, BEAM_THICKNESS) if absf(a.x - b.x) > 0.001 \
				else Vector3(BEAM_THICKNESS, BEAM_THICKNESS, length)
			var instance := MeshInstance3D.new()
			instance.mesh = segment
			instance.material_override = material
			instance.position = (a + b) * 0.5
			parent.add_child(instance)


## Compact description of the traced beams, to tell whether a preview changes them.
func beam_signature(state: PuzzleState) -> String:
	var parts := PackedStringArray()
	for beam: EnergyResolver.Beam in EnergyResolver.trace(_level, state):
		parts.append("%s:%s>%s" % [beam.emitter_id, str(beam.cells), beam.receiver_id])
	return ";".join(parts)


func magnet_label(magnet_id: String) -> String:
	return _magnet_labels[magnet_id].text if _magnet_labels.has(magnet_id) else ""


func magnet_cap(magnet_id: String) -> MeshInstance3D:
	return _magnet_caps.get(magnet_id)


## Polarity is always shown by colour AND symbol (docs/05 §4): + red, − blue (doc 06 palette).
## Uses the true minus sign U+2212 (as wide as "+" in the built-in Open Sans; a hyphen is a short dash).
## Level data keeps ASCII "+" / "-".
static func polarity_symbol(positive: bool) -> String:
	return "+" if positive else "\u2212"


static func polarity_color(positive: bool) -> Color:
	return Palette.POLARITY_RED if positive else Palette.POLARITY_BLUE


static func polarity_material(library: MaterialLibrary, positive: bool) -> StandardMaterial3D:
	return library.get_material("polarity_plus", Palette.POLARITY_RED, 1.0) if positive \
		else library.get_material("polarity_minus", Palette.POLARITY_BLUE, 1.0)


func beam_segment_count() -> int:
	return _beam_root.get_child_count()


func reflector_pivot(reflector_id: String) -> Node3D:
	return _reflector_pivots.get(reflector_id)


## The mirror slab's long axis lies along "/" or "\" (grid y down = world +Z).
static func reflector_yaw(slash: bool) -> float:
	return PI / 4.0 if slash else -PI / 4.0


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
		# Inverted gates (D-035) carry a "¬" so the difference reads without colour.
		symbols[level.gates[i].id] = ("¬" if level.gates[i].inverted else "") + String.chr("A".unicode_at(0) + i)
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
	if switch_def.kind == SwitchDefinition.Kind.RECEIVER:
		# A pedestal with a crystal lamp that lights while a beam reaches it.
		var pedestal := CylinderMesh.new()
		pedestal.top_radius = 0.22
		pedestal.bottom_radius = 0.32
		pedestal.height = 0.24
		var base := _mesh(pedestal, at + Vector3(0, 0.12, 0))
		base.material_override = _metal()
		var crystal := SphereMesh.new()
		crystal.radius = 0.17
		crystal.height = 0.34
		_switch_lamps[switch_def.id] = _mesh(crystal, at + Vector3(0, BEAM_HEIGHT, 0))
		_switch_bases[switch_def.id] = base
	elif switch_def.kind == SwitchDefinition.Kind.PRESSURE:
		# A square plate that lights up while pressed: the plate is its own lamp.
		var plate := BoxMesh.new()
		plate.size = Vector3(0.72, 0.05, 0.72)
		var lamp := _mesh(plate, at + Vector3(0, 0.025, 0))
		_switch_lamps[switch_def.id] = lamp
		_switch_bases[switch_def.id] = lamp
	else:
		# A machined pedestal with a lever arm that tips over when switched; the lamp is its knob.
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 0.3
		base_mesh.bottom_radius = 0.36
		base_mesh.height = 0.12
		base_mesh.radial_segments = 8
		var base := _mesh(base_mesh, at + Vector3(0, 0.06, 0), true)
		base.material_override = _metal()
		var collar := TorusMesh.new()
		collar.inner_radius = 0.24
		collar.outer_radius = 0.28
		collar.rings = 8
		collar.ring_segments = 4
		var collar_node := _mesh(collar, at + Vector3(0, 0.125, 0))
		collar_node.material_override = _library.glow("lever_collar", Palette.MECHANISM_AMBER, 1.2)
		var pivot := Node3D.new()
		pivot.position = at + Vector3(0, 0.13, 0)
		add_child(pivot)
		var arm := CylinderMesh.new()
		arm.top_radius = 0.035
		arm.bottom_radius = 0.05
		arm.height = 0.34
		arm.radial_segments = 8
		var arm_node := MeshInstance3D.new()
		arm_node.mesh = arm
		arm_node.position = Vector3(0, 0.17, 0)
		arm_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm_node.material_override = _library.get_material("lever_arm", Palette.METAL_HIGHLIGHT, 0.0, 1.0, 0.8, 0.3)
		pivot.add_child(arm_node)
		var knob := SphereMesh.new()
		knob.radius = 0.09
		knob.height = 0.18
		knob.radial_segments = 12
		knob.rings = 6
		var knob_node := MeshInstance3D.new()
		knob_node.mesh = knob
		knob_node.position = Vector3(0, 0.36, 0)
		knob_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(knob_node)
		_switch_lamps[switch_def.id] = knob_node
		_switch_bases[switch_def.id] = base
		_lever_arms[switch_def.id] = pivot
	# Above block height, so a block resting on the switch never hides or collides with the label.
	_label(switch_def.id, at + Vector3(0, LABEL_HEIGHT + 0.1, 0), Palette.TEXT)


## The world's own gate (PieceKit) in the gate's colour. Closed gates stand on the cell; open ones
## sink into the floor so only their glowing top shows.
func _build_gate(gate: GateDefinition) -> void:
	var color := Palette.GATE_INVERTED if gate.inverted else Palette.MECHANISM_AMBER
	var node := _pieces.gate(color, gate.inverted)
	node.position = BoardCoords.cell_to_world(gate.position)
	add_child(node)
	node.name = "Gate_%s" % gate.id
	_gates[gate.id] = node
	_label(gate.id, BoardCoords.cell_to_world(gate.position, LABEL_HEIGHT), color)


func _build_emitter(emitter: EmitterDefinition) -> void:
	var at := BoardCoords.cell_to_world(emitter.position)
	var body := BoxMesh.new()
	body.size = Vector3(0.7, 0.55, 0.7)
	var node := _mesh(body, at + Vector3(0, 0.27, 0))
	node.material_override = _metal()
	var nozzle := BoxMesh.new()
	nozzle.size = Vector3(0.24, 0.24, 0.24)
	var step := Grid.offset(emitter.direction)
	var tip := _mesh(nozzle, at + Vector3(step.x * 0.38, BEAM_HEIGHT, step.y * 0.38))
	tip.material_override = _library.get_material("emitter_nozzle", Palette.CYAN_ENERGY, 2.0)


func _build_reflector(reflector: ReflectorDefinition) -> void:
	var pivot := Node3D.new()
	pivot.name = "Mirror_%s" % reflector.id
	pivot.position = BoardCoords.cell_to_world(reflector.position)
	add_child(pivot)
	_reflector_pivots[reflector.id] = pivot
	var base := CylinderMesh.new()
	base.top_radius = 0.34
	base.bottom_radius = 0.38
	base.height = 0.1
	var base_node := MeshInstance3D.new()
	base_node.mesh = base
	base_node.position = Vector3(0, 0.05, 0)
	base_node.material_override = _metal()
	pivot.add_child(base_node)
	_switch_bases[reflector.id] = base_node
	var slab := BoxMesh.new()
	slab.size = Vector3(1.0, 0.55, 0.08)
	var mirror := MeshInstance3D.new()
	mirror.mesh = slab
	mirror.position = Vector3(0, 0.33, 0)
	mirror.material_override = _library.get_material("mirror", Palette.METAL_HIGHLIGHT, 0.4, 1.0, 0.9, 0.08)
	pivot.add_child(mirror)


func _build_magnet(magnet: MagnetDefinition) -> void:
	var at := BoardCoords.cell_to_world(magnet.position)
	var body := CylinderMesh.new()
	body.top_radius = 0.3
	body.bottom_radius = 0.36
	body.height = 0.5
	var base := _mesh(body, at + Vector3(0, 0.25, 0))
	base.material_override = _metal()
	_switch_bases[magnet.id] = base
	var cap := CylinderMesh.new()
	cap.top_radius = 0.3
	cap.bottom_radius = 0.3
	cap.height = 0.12
	_magnet_caps[magnet.id] = _mesh(cap, at + Vector3(0, 0.56, 0))
	var label := Label3D.new()
	label.position = at + Vector3(0, 1.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 150
	label.pixel_size = 0.005
	label.outline_size = 16
	add_child(label)
	_magnet_labels[magnet.id] = label


func _emitter(emitter_id: String) -> EmitterDefinition:
	for emitter: EmitterDefinition in _level.emitters:
		if emitter.id == emitter_id:
			return emitter
	return null


static func _direction_of(step: Vector2i) -> Grid.Direction:
	for direction: int in 4:
		if Grid.offset(direction as Grid.Direction) == step:
			return direction as Grid.Direction
	return Grid.Direction.UP


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
	_label(portal.id, at + Vector3(0, LABEL_HEIGHT + 0.1, 0), Palette.PORTAL_VIOLET)


func _portal_active(state: PuzzleState, portal: PortalDefinition) -> bool:
	if portal.exit_id != "":
		return SwitchGateResolver.is_portal_active(_level, state, portal)
	# An exit is lit when any entry leading to it is active.
	for other: PortalDefinition in _level.portals:
		if other.exit_id == portal.id and SwitchGateResolver.is_portal_active(_level, state, other):
			return true
	return false


func _lamp_material(on: bool) -> StandardMaterial3D:
	return _library.glow("lamp_on", Palette.MINT_SUCCESS, 2.2) if on \
		else _library.get_material("lamp_off", Palette.MECHANISM_AMBER.darkened(0.45), 0.3, 1.0, 0.2, 0.4)


func _metal() -> StandardMaterial3D:
	return _library.pbr("metal_plate", Color(0.6, 0.64, 0.7), 2.0, 0.7, 0.2, 1.0, false)


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
	label.outline_size = 18
	label.outline_modulate = Color(0.02, 0.04, 0.08, 0.9)
	label.modulate = color
	add_child(label)
	_labels[fixture_id] = label


## Small fixture parts cast no shadow (each caster costs a draw call per shadow pass); the
## bodies that need one (gates, pedestals) turn it back on.
func _mesh(mesh: Mesh, at: Vector3, shadow: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	if not shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
