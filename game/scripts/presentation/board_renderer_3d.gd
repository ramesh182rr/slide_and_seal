class_name BoardRenderer3D
extends Node3D
## Builds the 3D board from simulation data and places nodes to match a PuzzleState.
## Read-only with respect to the simulation: it never decides or changes puzzle rules.
## Placeholder primitive art (decision D-011).

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


## Rebuilds everything for `level`, then snaps to `state`.
func build(level: LevelDefinition, state: PuzzleState) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_objects.clear()
	_zone_chevrons.clear()
	_zone_plates.clear()
	_outline = null
	_level = level
	_build_floor()
	_build_walls()
	_build_route()
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
	_fixtures.sync_to_state(state)


func level() -> LevelDefinition:
	return _level


func fixtures() -> MechanismFixtures3D:
	return _fixtures


func core_node() -> Node3D:
	return _core


func object_node(object_id: String) -> Node3D:
	return _objects.get(object_id)


func zone_chevrons(zone_id: String) -> Array:
	return _zone_chevrons.get(zone_id, [])


## Highlights the selected block (outline that travels with it), zone or switch. Empty ids clear it.
func set_highlight(object_id: String, zone_id: String, switch_id: String = "") -> void:
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
	var base := BoxMesh.new()
	base.size = Vector3(size.x + 0.4, 0.4, size.y + 0.4)
	_add_mesh(base, _material("base", Palette.NAVY_SURFACE), BoardCoords.board_center(size) + Vector3(0, -0.4, 0))
	var tile := BoxMesh.new()
	tile.size = Vector3(TILE_SIZE, 0.2, TILE_SIZE)
	var tile_material := _material("tile", Palette.BOARD_SLATE)
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			if not _level.is_wall(cell):
				_add_mesh(tile, tile_material, BoardCoords.cell_to_world(cell, -0.1))


func _build_walls() -> void:
	var wall := BoxMesh.new()
	wall.size = Vector3(TILE_SIZE, WALL_HEIGHT, TILE_SIZE)
	var wall_material := _material("wall", Palette.WALL, 0.0, 1.0, 0.3, 0.7)
	for cell: Vector2i in _level.walls.keys():
		_add_mesh(wall, wall_material, BoardCoords.cell_to_world(cell, WALL_HEIGHT * 0.5 - 0.2))


## Emissive inlay along every route: a pad per node plus connectors between neighbours.
func _build_route() -> void:
	var inlay := _material("route", Palette.CYAN_ENERGY, 1.2)
	var pad := BoxMesh.new()
	pad.size = Vector3(0.22, 0.02, 0.22)
	var along_x := BoxMesh.new()
	along_x.size = Vector3(BoardCoords.CELL_SIZE, 0.02, 0.07)
	var along_z := BoxMesh.new()
	along_z.size = Vector3(0.07, 0.02, BoardCoords.CELL_SIZE)
	for route: RouteDefinition in _level.routes.values():
		for i: int in route.nodes.size():
			_add_mesh(pad, inlay, BoardCoords.cell_to_world(route.nodes[i], 0.01))
			if i > 0:
				var a := BoardCoords.cell_to_world(route.nodes[i - 1], 0.01)
				var b := BoardCoords.cell_to_world(route.nodes[i], 0.01)
				_add_mesh(along_x if route.nodes[i].y == route.nodes[i - 1].y else along_z, inlay, (a + b) * 0.5)


func _build_markers() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.27
	ring.outer_radius = 0.35
	var checkpoint_material := _material("checkpoint", Palette.MECHANISM_AMBER, 1.0)
	for route: RouteDefinition in _level.routes.values():
		for checkpoint: CheckpointDefinition in route.checkpoints:
			_add_mesh(ring, checkpoint_material, BoardCoords.cell_to_world(checkpoint.position, 0.03))
	var seal_ring := TorusMesh.new()
	seal_ring.inner_radius = 0.3
	seal_ring.outer_radius = 0.44
	var seal_material := _material("seal", Palette.MINT_SUCCESS, 1.6)
	_add_mesh(seal_ring, seal_material, BoardCoords.cell_to_world(_level.destination, 0.04))
	var seal_disc := CylinderMesh.new()
	seal_disc.top_radius = 0.18
	seal_disc.bottom_radius = 0.18
	seal_disc.height = 0.04
	_add_mesh(seal_disc, seal_material, BoardCoords.cell_to_world(_level.destination, 0.03))


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
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * BLOCK_SIZE
	var pushable_material := _material("block", Palette.METAL_HIGHLIGHT, 0.0, 1.0, 0.5, 0.35)
	var fixed_material := _material("block_fixed", Palette.BOARD_SLATE.lightened(0.15), 0.0, 1.0, 0.5, 0.5)
	for obj: MovableObject in state.objects:
		var node := _add_mesh(cube, pushable_material if obj.pushable else fixed_material, Vector3.ZERO)
		node.name = "Object_%s" % obj.id
		_objects[obj.id] = node


func _build_core() -> void:
	_core = _add_mesh(_octahedron(0.3, 0.4), _material("core", Palette.CYAN_ENERGY, 2.2, 1.0, 0.2, 0.15), Vector3.ZERO)
	_core.name = "Core"
	var glow := OmniLight3D.new()
	glow.light_color = Palette.CYAN_ENERGY
	glow.light_energy = 1.2
	glow.omni_range = 2.5
	_core.add_child(glow)


# --- Helpers ------------------------------------------------------------------

## Flat-shaded octahedron (the geometric energy core): `radius` at the equator, `half_height` to each tip.
static func _octahedron(radius: float, half_height: float) -> ArrayMesh:
	var top := Vector3(0, half_height, 0)
	var bottom := Vector3(0, -half_height, 0)
	var ring: Array[Vector3] = [Vector3(radius, 0, 0), Vector3(0, 0, -radius), Vector3(-radius, 0, 0), Vector3(0, 0, radius)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		for vertex: Vector3 in [top, b, a, bottom, a, b]:  # Clockwise winding = front faces in Godot.
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()

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
