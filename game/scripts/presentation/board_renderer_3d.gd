class_name BoardRenderer3D
extends Node3D
## Builds the 3D board from simulation data and places nodes to match a PuzzleState.
## Read-only with respect to the simulation: it never decides or changes puzzle rules.
## Art: procedural beveled stone, emissive inlays and a floating island themed per world
## (WorldTheme, M11). Idle motion (core spin, seal rings, drifting rocks) is decoration only.

const BLOCK_SIZE := 0.78
const BLOCK_HEIGHT := BLOCK_SIZE * 0.5
const CORE_HEIGHT := 0.45
const WALL_HEIGHT := 0.8
const TILE_SIZE := 0.94

var _level: LevelDefinition
var _core: Node3D
var _objects: Dictionary[String, Node3D] = {}
## Chevron pivots per gravity zone; rotating a pivot about +Y points its chevron.
var _zone_chevrons: Dictionary[String, Array] = {}
var _zone_plates: Dictionary[String, MeshInstance3D] = {}
var _library := MaterialLibrary.new()
var _fixtures: MechanismFixtures3D
var _outline: MeshInstance3D
var _preview_root: Node3D
## Per rotating section: a pivot at the section centre carrying everything inside it, and a fixed frame.
var _section_pivots: Dictionary[String, Node3D] = {}
var _section_frames: Dictionary[String, MeshInstance3D] = {}
## Static geometry merged per (parent, material) into one mesh each: a board has hundreds of
## tiles, walls and inlay pieces, and one draw call each was the main cost on phones.
## Entries: {"parent": Node3D, "material": Material, "shadow": bool, "tool": SurfaceTool, "name": String}.
var _batches: Array[Dictionary] = []
var _theme: WorldTheme = WorldTheme.for_world("")
var _decor: IslandDecor
## Idle-animated decoration: spun about +Y each frame (core crystal, seal rings).
var _spinners: Array[Node3D] = []
var _spin_speeds: Array[float] = []
## Turn off for still screenshots.
var animate := true


## Rebuilds everything for `level`, then snaps to `state`.
func build(level: LevelDefinition, state: PuzzleState) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_objects.clear()
	_zone_chevrons.clear()
	_zone_plates.clear()
	_section_pivots.clear()
	_section_frames.clear()
	_batches.clear()
	_spinners.clear()
	_spin_speeds.clear()
	_outline = null
	_level = level
	_theme = WorldTheme.for_world(level.world_id)
	_decor = IslandDecor.new()
	_decor.name = "Island"
	_decor.animate = animate
	add_child(_decor)
	_decor.build(level.board_size, _theme, _library)
	_build_section_pivots()
	_build_floor()
	_build_walls()
	_build_route()
	_flush_batches()
	_build_markers()
	_build_gravity_zones()
	_fixtures = MechanismFixtures3D.new()
	_fixtures.name = "Fixtures"
	add_child(_fixtures)
	_fixtures.build(level, _library)
	_build_objects(state)
	_build_core()
	_preview_root = Node3D.new()
	_preview_root.name = "Preview"
	add_child(_preview_root)
	sync_to_state(state)


## Snaps every dynamic node to the committed state. Authoritative after any animation.
func sync_to_state(state: PuzzleState) -> void:
	_core.position = core_world_position(PuzzleSimulator.core_position(_level, state))
	for obj: MovableObject in state.objects:
		_objects[obj.id].position = object_world_position(obj.position)
	for zone_id: String in state.gravity_directions.keys():
		for pivot: Node3D in _zone_chevrons[zone_id]:
			pivot.rotation.y = BoardCoords.direction_yaw(state.gravity_directions[zone_id])
	for section_id: String in state.section_turns.keys():
		_section_pivots[section_id].rotation.y = section_yaw(state.section_turns[section_id])
	_fixtures.sync_to_state(state)


func level() -> LevelDefinition:
	return _level


func fixtures() -> MechanismFixtures3D:
	return _fixtures


func section_pivot(section_id: String) -> Node3D:
	return _section_pivots.get(section_id)


## Clockwise quarter turns on the grid (y down) are negative rotations about +Y in the world.
static func section_yaw(turns: int) -> float:
	return -posmod(turns, 4) * PI / 2.0


func core_node() -> Node3D:
	return _core


func world_theme() -> WorldTheme:
	return _theme


func decor() -> IslandDecor:
	return _decor


func set_animate(enabled: bool) -> void:
	animate = enabled
	if _decor != null:
		_decor.animate = enabled


func _process(delta: float) -> void:
	if not animate:
		return
	for i: int in _spinners.size():
		_spinners[i].rotate_y(delta * _spin_speeds[i])


func object_node(object_id: String) -> Node3D:
	return _objects.get(object_id)


func zone_chevrons(zone_id: String) -> Array:
	return _zone_chevrons.get(zone_id, [])


## Highlights the selected block (outline that travels with it), zone or switch. Empty ids clear it.
func set_highlight(object_id: String, zone_id: String, switch_id: String = "", section_id: String = "") -> void:
	if _outline != null:
		_outline.get_parent().remove_child(_outline)
		_outline.free()
		_outline = null
	if object_id != "" and _objects.has(object_id):
		var shell := BoxMesh.new()
		shell.size = Vector3.ONE * (BLOCK_SIZE + 0.2)
		_outline = _add_mesh(shell, _outline_material(), Vector3.ZERO, _objects[object_id])
	elif switch_id != "" and _fixtures.switch_base(switch_id) != null:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.46
		ring.bottom_radius = 0.46
		ring.height = 0.16
		_outline = _add_mesh(ring, _outline_material(), Vector3.ZERO, _fixtures.switch_base(switch_id))
	for id: String in _section_frames.keys():
		_section_frames[id].material_override = _material("section_frame_selected", Palette.CYAN_ENERGY, 1.2) \
			if id == section_id else _material("section_frame", Palette.MECHANISM_AMBER, 0.5)
	for id: String in _zone_plates.keys():
		_zone_plates[id].material_override = _material("zone_plate_selected", Palette.CYAN_ENERGY, 0.6, 0.32) \
			if id == zone_id else _material("zone_plate", Palette.POLARITY_BLUE, 0.3, 0.2)


func highlighted_object_id() -> String:
	if _outline == null:
		return ""
	for id: String in _objects.keys():
		if _objects[id] == _outline.get_parent():
			return id
	return ""


## Shows translucent ghosts where blocks would end up, comparing a preview state to the current one.
func show_preview(current: PuzzleState, previewed: PuzzleState) -> void:
	clear_preview()
	var ghost := BoxMesh.new()
	ghost.size = Vector3.ONE * BLOCK_SIZE
	var material := _material("ghost", Palette.CYAN_ENERGY, 0.8, 0.35)
	for obj: MovableObject in previewed.objects:
		var now := current.object_by_id(obj.id)
		if now != null and now.position != obj.position:
			_add_mesh(ghost, material, object_world_position(obj.position), _preview_root)
	_fixtures.add_preview_ghosts(_preview_root, current, previewed)
	# Where the beams would run (docs/03 §6: "beam preview should show the full route").
	if _fixtures.beam_signature(current) != _fixtures.beam_signature(previewed):
		_fixtures.add_beams(_preview_root, previewed, true)
	# Where each track piece would lie after a previewed turn.
	var pad := BoxMesh.new()
	pad.size = Vector3(0.3, 0.06, 0.3)
	for route: RouteDefinition in _level.routes.values():
		if route.section_id == "" or current.section_turns[route.section_id] == previewed.section_turns[route.section_id]:
			continue
		var section := _level.rotating_section(route.section_id)
		for node: Vector2i in route.nodes:
			var cell := section.rotate_cell(node, previewed.section_turns[route.section_id])
			_add_mesh(pad, material, BoardCoords.cell_to_world(cell, 0.06), _preview_root)


func clear_preview() -> void:
	for child: Node in _preview_root.get_children():
		_preview_root.remove_child(child)
		child.free()


func preview_ghost_count() -> int:
	return _preview_root.get_child_count()


static func core_world_position(cell: Vector2i) -> Vector3:
	return BoardCoords.cell_to_world(cell, CORE_HEIGHT)


static func object_world_position(cell: Vector2i) -> Vector3:
	return BoardCoords.cell_to_world(cell, BLOCK_HEIGHT)


# --- Static board -------------------------------------------------------------

func _build_floor() -> void:
	var size := _level.board_size
	# The plinth: a thick beveled slab under the tiles (its gaps read as grout), with a glowing
	# accent line around its top edge.
	var plinth := _library.surface("plinth", 0.9, 0.05, 0.5)
	var extent := Vector3(size.x + 0.36, 0.5, size.y + 0.36)
	var centre := BoardCoords.board_center(size)
	var plinth_tool := _batch("plinth", plinth, null, false)
	MeshKit.append_bevel_box(plinth_tool["tool"], centre + Vector3(0, -0.45, 0), extent, 0.08,
		_theme.stone_dark.darkened(0.25), _theme.stone_dark.darkened(0.45))
	var edge := _library.glow("plinth_edge", _theme.accent, 1.6)
	for side: int in 4:
		var line := BoxMesh.new()
		var along_x := side < 2
		line.size = Vector3(extent.x - 0.1, 0.035, 0.02) if along_x else Vector3(0.02, 0.035, extent.z - 0.1)
		var offset := Vector3(0, -0.3, (extent.z * 0.5 + 0.005) * (1 if side == 0 else -1)) if along_x \
			else Vector3((extent.x * 0.5 + 0.005) * (1 if side == 2 else -1), -0.3, 0)
		_batch_at_world("plinth_edge", line, edge, centre + offset, null, false)
	var stone := _library.surface("tile_stone", 0.86, 0.0, 0.6)
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			if _level.is_wall(cell):
				continue
			var section := _level.section_at(cell)
			var top := _tile_color(cell, section != null)
			var batch := _batch("floor", stone, section, false)
			MeshKit.append_bevel_box(batch["tool"], BoardCoords.cell_to_world(cell, -0.1) - batch["origin"],
				Vector3(TILE_SIZE, 0.2, TILE_SIZE), 0.05, top, _theme.stone_dark,
				Vector2(MeshKit.hash01(x, y, 1), MeshKit.hash01(x, y, 2)) * 8.0)


## Stone varies a little from tile to tile; where the world has foliage, a few tiles are mossy.
## Turntable tiles are a brighter, worked stone so the rotating platform reads as one piece.
func _tile_color(cell: Vector2i, turntable: bool) -> Color:
	var shade := (MeshKit.hash01(cell.x, cell.y, 3) - 0.5) * 0.16
	var color := _theme.stone.lightened(shade) if shade > 0.0 else _theme.stone.darkened(-shade)
	if turntable:
		return _theme.stone.lightened(0.22)
	if MeshKit.hash01(cell.x, cell.y, 4) < _theme.foliage.a * 0.22:
		color = color.lerp(Color(_theme.foliage, 1.0), 0.28)
	return color


func _build_walls() -> void:
	var stone := _library.surface("wall_stone", 0.82, 0.0, 0.6)
	var trim := _library.glow("wall_trim", _theme.accent.darkened(0.15), 1.25)
	var top_color := _theme.stone.lightened(0.16)
	var side_color := _theme.stone.darkened(0.12)
	var band_x := BoxMesh.new()
	band_x.size = Vector3(TILE_SIZE - 0.16, 0.035, 0.012)
	var band_z := BoxMesh.new()
	band_z.size = Vector3(0.012, 0.035, TILE_SIZE - 0.16)
	var trim_y := WALL_HEIGHT - 0.38
	for cell: Vector2i in _level.walls.keys():
		var section := _level.section_at(cell)
		var batch := _batch("walls", stone, section, true)
		var shade := (MeshKit.hash01(cell.x, cell.y, 5) - 0.5) * 0.12
		MeshKit.append_bevel_box(batch["tool"], BoardCoords.cell_to_world(cell, WALL_HEIGHT * 0.5 - 0.2) - batch["origin"],
			Vector3(TILE_SIZE, WALL_HEIGHT, TILE_SIZE), 0.07, top_color.lightened(shade), side_color,
			Vector2(MeshKit.hash01(cell.x, cell.y, 6), MeshKit.hash01(cell.x, cell.y, 7)) * 8.0)
		# A thin glowing seam around each block: engineered stone (docs/06 §3 "emissive inlays").
		var at := BoardCoords.cell_to_world(cell, trim_y)
		var face := TILE_SIZE * 0.5 + 0.006
		_batch_at_world("trim", band_x, trim, at + Vector3(0, 0, face), section, false)
		_batch_at_world("trim", band_x, trim, at + Vector3(0, 0, -face), section, false)
		_batch_at_world("trim", band_z, trim, at + Vector3(face, 0, 0), section, false)
		_batch_at_world("trim", band_z, trim, at + Vector3(-face, 0, 0), section, false)


## Emissive inlay along every route: a diamond stud per node plus connectors between neighbours.
func _build_route() -> void:
	var inlay := _library.glow("route", Palette.CYAN_ENERGY, 2.6)
	var groove := _library.get_material("route_groove", Palette.DEEP_BACKGROUND, 0.0, 1.0, 0.4, 0.5)
	var stud := BoxMesh.new()
	stud.size = Vector3(0.16, 0.025, 0.16)
	var along_x := BoxMesh.new()
	along_x.size = Vector3(BoardCoords.CELL_SIZE, 0.02, 0.055)
	var along_z := BoxMesh.new()
	along_z.size = Vector3(0.055, 0.02, BoardCoords.CELL_SIZE)
	var groove_x := BoxMesh.new()
	groove_x.size = Vector3(BoardCoords.CELL_SIZE, 0.012, 0.13)
	var groove_z := BoxMesh.new()
	groove_z.size = Vector3(0.13, 0.012, BoardCoords.CELL_SIZE)
	var diamond := Basis(Vector3.UP, PI / 4.0)
	for route: RouteDefinition in _level.routes.values():
		for i: int in route.nodes.size():
			var section := _level.section_at(route.nodes[i])
			var batch := _batch("route", inlay, section, false)
			(batch["tool"] as SurfaceTool).append_from(stud, 0,
				Transform3D(diamond, BoardCoords.cell_to_world(route.nodes[i], 0.014) - batch["origin"]))
			if i > 0:
				var a := BoardCoords.cell_to_world(route.nodes[i - 1], 0.01)
				var b := BoardCoords.cell_to_world(route.nodes[i], 0.01)
				var horizontal := route.nodes[i].y == route.nodes[i - 1].y
				_batch_at_world("route", along_x if horizontal else along_z, inlay, (a + b) * 0.5, section, false)
				# A dark channel either side of the light, as if cut into the stone.
				_batch_at_world("route_groove", groove_x if horizontal else groove_z, groove,
					(a + b) * 0.5 + Vector3(0, -0.004, 0), section, false)


func _build_markers() -> void:
	var medallion := CylinderMesh.new()
	medallion.top_radius = 0.36
	medallion.bottom_radius = 0.38
	medallion.height = 0.03
	medallion.radial_segments = 8
	var ring := TorusMesh.new()
	ring.inner_radius = 0.27
	ring.outer_radius = 0.33
	ring.rings = 8
	ring.ring_segments = 4
	var dark := _library.get_material("marker_base", _theme.stone_dark.darkened(0.3), 0.0, 1.0, 0.6, 0.35)
	var checkpoint_material := _library.glow("checkpoint", Palette.MECHANISM_AMBER, 1.8)
	for route: RouteDefinition in _level.routes.values():
		for checkpoint: CheckpointDefinition in route.checkpoints:
			var at := BoardCoords.cell_to_world(checkpoint.position)
			var base := _add_at_world(medallion, dark, at + Vector3(0, 0.012, 0), _level.section_at(checkpoint.position))
			base.rotation.y = PI / 8.0
			base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var glow_ring := _add_at_world(ring, checkpoint_material, at + Vector3(0, 0.03, 0), _level.section_at(checkpoint.position))
			glow_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add_glow_pool(at, Palette.MECHANISM_AMBER, 0.9, 0.35)
	_build_seal()


## The destination: a hexagonal seal pad with a turning ring and a soft column of light.
func _build_seal() -> void:
	var at := BoardCoords.cell_to_world(_level.destination)
	var root := Node3D.new()
	root.name = "Seal"
	root.position = at
	add_child(root)
	var pad := CylinderMesh.new()
	pad.top_radius = 0.44
	pad.bottom_radius = 0.47
	pad.height = 0.06
	pad.radial_segments = 6
	var pad_node := _add_mesh(pad, _library.get_material("seal_pad", _theme.stone_dark.darkened(0.2), 0.0, 1.0, 0.7, 0.3),
		Vector3(0, 0.03, 0), root)
	pad_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var seal_material := _library.glow("seal", Palette.MINT_SUCCESS, 2.0)
	var outer := TorusMesh.new()
	outer.inner_radius = 0.34
	outer.outer_radius = 0.4
	outer.rings = 6
	outer.ring_segments = 4
	_add_mesh(outer, seal_material, Vector3(0, 0.07, 0), root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spinner := Node3D.new()
	spinner.position = Vector3(0, 0.09, 0)
	root.add_child(spinner)
	var inner := TorusMesh.new()
	inner.inner_radius = 0.16
	inner.outer_radius = 0.2
	inner.rings = 6
	inner.ring_segments = 4
	_add_mesh(inner, seal_material, Vector3.ZERO, spinner).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var heart := CylinderMesh.new()
	heart.top_radius = 0.08
	heart.bottom_radius = 0.08
	heart.height = 0.02
	heart.radial_segments = 6
	_add_mesh(heart, seal_material, Vector3.ZERO, spinner).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin(spinner, 0.9)
	var column := CylinderMesh.new()
	column.top_radius = 0.2
	column.bottom_radius = 0.3
	column.height = 1.4
	column.radial_segments = 12
	column.cap_top = false
	column.cap_bottom = false
	var beam := _add_mesh(column, _library.glow("seal_column", Palette.MINT_SUCCESS, 0.9, 0.16), Vector3(0, 0.75, 0), root)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_glow_pool(at, Palette.MINT_SUCCESS, 1.4, 0.55)


## A soft additive glow on the floor (no light source: cheap on phones).
func _add_glow_pool(at: Vector3, color: Color, diameter: float, strength: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * diameter
	quad.orientation = PlaneMesh.FACE_Y
	var key := "pool_%s_%.2f" % [color.to_html(), strength]
	var material := _library.glow(key, color, strength, 1.0)
	if material.albedo_texture == null:
		material.albedo_texture = _radial_texture()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var node := _add_mesh(quad, material, at + Vector3(0, 0.022, 0))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _radial: GradientTexture2D


static func _radial_texture() -> GradientTexture2D:
	if _radial == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.35))
		_radial = GradientTexture2D.new()
		_radial.gradient = gradient
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 128
		_radial.height = 128
	return _radial


func _spin(node: Node3D, speed: float) -> void:
	_spinners.append(node)
	_spin_speeds.append(speed)


## Translucent plate over each zone plus one chevron per cell showing the current direction.
func _build_gravity_zones() -> void:
	var plate_material := _material("zone_plate", Palette.POLARITY_BLUE, 0.3, 0.2)
	var chevron_material := _material("zone_chevron", Palette.POLARITY_BLUE, 0.9)
	# Long and narrow so the pointing direction reads clearly at an isometric angle.
	var chevron := PrismMesh.new()
	chevron.size = Vector3(0.2, 0.42, 0.02)
	for zone: GravityZoneDefinition in _level.gravity_zones:
		var plate := BoxMesh.new()
		plate.size = Vector3(zone.rect.size.x - 0.08, 0.012, zone.rect.size.y - 0.08)
		_zone_plates[zone.id] = _add_mesh(plate, plate_material, BoardCoords.rect_center(zone.rect, 0.008))
		var pivots: Array[Node3D] = []
		for y: int in range(zone.rect.position.y, zone.rect.end.y):
			for x: int in range(zone.rect.position.x, zone.rect.end.x):
				var pivot := Node3D.new()
				pivot.position = BoardCoords.cell_to_world(Vector2i(x, y), 0.025)
				add_child(pivot)
				# Prism apex is +Y; tip it forward so it lies flat pointing at world -Z (grid UP).
				var mesh := _add_mesh(chevron, chevron_material, Vector3.ZERO, pivot)
				mesh.rotation.x = -PI / 2.0
				pivots.append(pivot)
		_zone_chevrons[zone.id] = pivots


# --- Dynamic pieces -----------------------------------------------------------

func _build_objects(state: PuzzleState) -> void:
	var metal := _library.surface("block_metal", 0.45, 0.25, 0.8, 0.5)
	var pushable_mesh := MeshKit.bevel_box(Vector3.ONE * BLOCK_SIZE, 0.07, Palette.METAL_HIGHLIGHT.darkened(0.05),
		Palette.METAL_HIGHLIGHT.darkened(0.3))
	var fixed_mesh := MeshKit.bevel_box(Vector3.ONE * BLOCK_SIZE, 0.07, Palette.METAL_HIGHLIGHT.darkened(0.2),
		Palette.METAL_HIGHLIGHT.darkened(0.45))
	# Pushable blocks carry a glowing square on top: they are the pieces that move.
	var lamp := _library.glow("block_lamp", Palette.CYAN_ENERGY, 1.6)
	var frame := TorusMesh.new()
	frame.inner_radius = 0.2
	frame.outer_radius = 0.235
	frame.rings = 4
	frame.ring_segments = 3
	var band := BoxMesh.new()
	band.size = Vector3(BLOCK_SIZE + 0.02, 0.12, BLOCK_SIZE + 0.02)
	# Every block that can move has lit corner edges, so blocks never read as wall stubs.
	var edge := BoxMesh.new()
	edge.size = Vector3(0.035, BLOCK_SIZE * 0.8, 0.035)
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var c := corner * (BLOCK_SIZE * 0.5 - 0.005)
		edges.append_from(edge, 0, Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.y)))
	var edge_mesh := edges.commit()
	var edge_material := _library.glow("block_edge", Color("#CFE6FF"), 1.3)
	for obj: MovableObject in state.objects:
		var node := _add_mesh(pushable_mesh if obj.pushable else fixed_mesh, metal, Vector3.ZERO)
		node.name = "Object_%s" % obj.id
		_objects[obj.id] = node
		var lit := _add_mesh(edge_mesh, edge_material, Vector3.ZERO, node)
		lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if obj.pushable:
			var mark := _add_mesh(frame, lamp, Vector3(0, BLOCK_SIZE * 0.5 + 0.005, 0), node)
			mark.rotation.y = PI / 4.0
			mark.scale = Vector3(1, 0.3, 1)
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if obj.polarity != 0:
			# Magnetic blocks: a coloured band and a +/- symbol (colour is never the only cue).
			var positive := obj.polarity > 0
			_add_mesh(band, MechanismFixtures3D.polarity_material(_library, positive), Vector3(0, 0.2, 0), node)
			var label := Label3D.new()
			label.name = "Polarity"
			label.text = MechanismFixtures3D.polarity_symbol(positive)
			label.modulate = MechanismFixtures3D.polarity_color(positive)
			label.position = Vector3(0, BLOCK_SIZE * 0.5 + 0.2, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.font_size = 130
			label.pixel_size = 0.005
			label.outline_size = 14
			node.add_child(label)


## The energy core: a glowing crystal with a bright heart and a tilted orbit ring.
func _build_core() -> void:
	_core = Node3D.new()
	_core.name = "Core"
	add_child(_core)
	var spinner := Node3D.new()
	spinner.name = "Crystal"
	_core.add_child(spinner)
	_add_mesh(MeshKit.octahedron(0.28, 0.4), _library.crystal("core", Palette.CYAN_ENERGY, 2.4, 0.9), Vector3.ZERO, spinner)
	_add_mesh(MeshKit.octahedron(0.12, 0.18), _library.glow("core_heart", Color(0.85, 1.0, 1.0), 3.0), Vector3.ZERO,
		spinner).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin(spinner, 1.1)
	var orbit := Node3D.new()
	orbit.rotation = Vector3(0.45, 0, 0.2)
	_core.add_child(orbit)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.445
	ring.rings = 24
	ring.ring_segments = 4
	var ring_node := _add_mesh(ring, _library.glow("core_ring", Palette.CYAN_ENERGY, 1.8), Vector3.ZERO, orbit)
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin(orbit, -0.7)
	# A glow pool on the floor instead of a point light: on phones (Compatibility renderer) every
	# object a light reaches is drawn again, so the core lights its surroundings this way for free.
	var pool := QuadMesh.new()
	pool.size = Vector2.ONE * 1.5
	pool.orientation = PlaneMesh.FACE_Y
	var pool_material := _library.glow("core_pool", Palette.CYAN_ENERGY, 0.7, 1.0)
	if pool_material.albedo_texture == null:
		pool_material.albedo_texture = _radial_texture()
		pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var pool_node := _add_mesh(pool, pool_material, Vector3(0, -CORE_HEIGHT + 0.03, 0), _core)
	pool_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A pivot per section (content at authored orientation; turned in sync_to_state), a fixed frame
## outlining the square, and a hub on the pivot that visibly turns.
func _build_section_pivots() -> void:
	for section: RotatingSectionDefinition in _level.rotating_sections:
		var pivot := Node3D.new()
		pivot.name = "Section_%s" % section.id
		pivot.position = BoardCoords.rect_center(section.rect())
		add_child(pivot)
		_section_pivots[section.id] = pivot
		var frame := TorusMesh.new()
		frame.inner_radius = section.size * 0.5 * 1.32
		frame.outer_radius = section.size * 0.5 * 1.42
		frame.rings = 4
		frame.ring_segments = 4
		var frame_node := _add_mesh(frame, _material("section_frame", Palette.MECHANISM_AMBER, 0.5),
			pivot.position + Vector3(0, -0.02, 0))
		frame_node.rotation.y = PI / 4.0  # A 4-sided torus, turned to sit square with the grid.
		_section_frames[section.id] = frame_node
		var hub := CylinderMesh.new()
		hub.top_radius = 0.14
		hub.bottom_radius = 0.14
		hub.height = 0.05
		var hub_node := _add_mesh(hub, _material("section_hub", Palette.MECHANISM_AMBER, 0.8), Vector3(0, 0.03, 0), pivot)
		hub_node.position.x = 0.32  # Off-centre so the turn is visible even on an empty section.


## Places a mesh for `cell`: on its section's pivot when inside a section, otherwise on the board.
func _add_at_cell(mesh: Mesh, material: Material, cell: Vector2i, height: float) -> MeshInstance3D:
	return _add_at_world(mesh, material, BoardCoords.cell_to_world(cell, height), _level.section_at(cell))


func _add_at_world(mesh: Mesh, material: Material, world: Vector3, section: RotatingSectionDefinition) -> MeshInstance3D:
	if section == null:
		return _add_mesh(mesh, material, world)
	var pivot := _section_pivots[section.id]
	return _add_mesh(mesh, material, world - pivot.position, pivot)


# --- Static batching ------------------------------------------------------------

func _batch_at_cell(group: String, mesh: PrimitiveMesh, material: Material, cell: Vector2i, height: float,
		shadow: bool) -> void:
	_batch_at_world(group, mesh, material, BoardCoords.cell_to_world(cell, height), _level.section_at(cell), shadow)


## Like _add_at_world, but appends the mesh to its (parent, material) batch instead of adding a node.
func _batch_at_world(group: String, mesh: PrimitiveMesh, material: Material, world: Vector3,
		section: RotatingSectionDefinition, shadow: bool) -> void:
	var batch := _batch(group, material, section, shadow)
	(batch["tool"] as SurfaceTool).append_from(mesh, 0, Transform3D(Basis.IDENTITY, world - (batch["origin"] as Vector3)))


## The batch for (section pivot or board, material). Geometry appended to batch["tool"] must be in
## the parent's space: world position minus batch["origin"].
func _batch(group: String, material: Material, section: RotatingSectionDefinition, shadow: bool) -> Dictionary:
	var parent: Node3D = self if section == null else _section_pivots[section.id]
	for entry: Dictionary in _batches:
		if entry["parent"] == parent and entry["material"] == material:
			return entry
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var batch := {"parent": parent, "material": material, "shadow": shadow, "tool": tool,
		"origin": Vector3.ZERO if section == null else parent.position,
		"name": "Static_%s_%d" % [group, _batches.size()]}
	_batches.append(batch)
	return batch


func _flush_batches() -> void:
	for batch: Dictionary in _batches:
		var instance := MeshInstance3D.new()
		instance.name = batch["name"]
		instance.mesh = (batch["tool"] as SurfaceTool).commit()
		instance.material_override = batch["material"]
		if not batch["shadow"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(batch["parent"] as Node3D).add_child(instance)
	_batches.clear()


## Static batches under `parent` (tests and diagnostics).
func static_batches(parent: Node3D = self) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in parent.get_children():
		if child is MeshInstance3D and child.name.begins_with("Static_"):
			found.append(child)
	return found


# --- Helpers ------------------------------------------------------------------

func _add_mesh(mesh: Mesh, material: Material, position_value: Vector3, parent: Node = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	parent.add_child(instance)
	return instance


func _outline_material() -> StandardMaterial3D:
	return _library.outline()


func _material(key: String, color: Color, emission: float = 0.0, alpha: float = 1.0,
		metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	return _library.get_material(key, color, emission, alpha, metallic, roughness)
