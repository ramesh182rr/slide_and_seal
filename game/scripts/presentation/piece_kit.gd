class_name PieceKit
extends RefCounted
## The playing pieces of one world (M15): movable blocks, gates and the energy core, each with a
## form and material that belongs to its world (WorldTheme.Style). What a piece *means* never
## changes between worlds: pushable blocks carry the cyan top mark, gates are amber (pink when
## inverted) with their letter, the core is cyan. Sizes match the simulation's cells and the
## picker's block box in every style. Presentation only.
##
## Meshes are built once per kit and shared by every piece of that kind; decoration is merged per
## material, so a piece costs two to four draw calls.

const S := BoardRenderer3D.BLOCK_SIZE
const GATE_SIZE := 0.86
const GOLD := Color("#F2C46A")
const LAVA := Color("#FF8A2A")
const NEON_TEAL := Color("#3FF2E0")
const NEON_MAGENTA := Color("#FF3FA0")
const HAZARD := Color("#F2B824")

var _library: MaterialLibrary
var _theme: WorldTheme
## Cached parts: key → Array of [Mesh, Material].
var _parts: Dictionary = {}


func _init(library: MaterialLibrary, theme: WorldTheme) -> void:
	_library = library
	_theme = theme


# --- Blocks -------------------------------------------------------------------------

## A movable block for this world. Pushable blocks are brighter and carry the cyan top mark.
func block(pushable: bool) -> MeshInstance3D:
	var key := "block_%s" % pushable
	if not _parts.has(key):
		_parts[key] = _block_parts(pushable)
	var node := _assemble(_parts[key], true)
	if pushable:
		_add_part(node, _push_mark(), _library.glow("block_lamp", Palette.CYAN_ENERGY, 1.6), false)
	return node


func _block_parts(pushable: bool) -> Array:
	var shade := 1.0 if pushable else 0.66
	var top := Color(shade, shade, shade)
	var side := Color(shade * 0.82, shade * 0.82, shade * 0.82)
	var parts: Array = []
	var decor := {}  # material → SurfaceTool
	match _theme.style:
		WorldTheme.Style.FROST:
			# A block of bright frosted ice: near-white against the deep blue floor.
			parts.append([MeshKit.bevel_box(Vector3.ONE * S, 0.1), _library.get_material(
				"ice_block" if pushable else "ice_block_dark",
				Color(0.82, 0.96, 1.0) if pushable else Color(0.5, 0.68, 0.86), 0.22, 1.0, 0.1, 0.12)])
			var frost := _library.glow("ice_block_edge", Color("#7FE3FF"), 1.4)
			_edge_frame(_tool(decor, frost), S * 0.5 - 0.03, 0.02)
		WorldTheme.Style.FOUNDRY:
			# A riveted steel crate with a hazard band.
			# Slate-blue painted steel: cool against the foundry's oranges, and unlike the amber gates.
			parts.append([MeshKit.bevel_box(Vector3.ONE * S, 0.05),
				_library.get_material("crate_paint" if pushable else "crate_paint_dark",
					Color(0.24, 0.56, 0.78) if pushable else Color(0.16, 0.36, 0.52), 0.0, 1.0, 0.25, 0.5)])
			var paint := _library.get_material("hazard_paint", HAZARD, 0.0, 1.0, 0.1, 0.55)
			var black := _library.get_material("hazard_black", Color(0.08, 0.08, 0.09), 0.0, 1.0, 0.1, 0.6)
			MeshKit.append_bevel_box(_tool(decor, paint), Vector3(0, 0.02, 0), Vector3(S + 0.012, 0.16, S + 0.012), 0.0,
				Color.WHITE, Color.WHITE)
			for y: float in [0.115, -0.075]:
				MeshKit.append_bevel_box(_tool(decor, black), Vector3(0, y, 0), Vector3(S + 0.016, 0.03, S + 0.016), 0.0,
					Color.WHITE, Color.WHITE)
			var steel := _library.pbr("metal_plate", Color(0.6, 0.64, 0.7), 2.0, 0.7, 0.2, 1.0, false)
			for corner: Vector2 in _corners():
				var c := corner * (S * 0.5 - 0.09)
				MeshKit.append_cylinder(_tool(decor, steel), Vector3(c.x, S * 0.5 - 0.01, c.y), Vector3(c.x, S * 0.5 + 0.03, c.y),
					0.045, Color.WHITE, 8)
		WorldTheme.Style.PORTAL:
			# A cut amethyst with a bright heart.
			parts.append([MeshKit.bevel_box(Vector3.ONE * S, 0.17), _library.get_material(
				"amethyst_block" if pushable else "amethyst_block_dark",
				Color(0.8, 0.22, 0.95) if pushable else Color(0.46, 0.14, 0.6), 0.35, 1.0, 0.2, 0.2)])
			parts.append([MeshKit.octahedron(0.16, 0.22), _library.glow("amethyst_heart", Color(0.9, 0.8, 1.0), 2.0)])
		WorldTheme.Style.TEMPLE:
			# Marble banded with gold.
			parts.append([MeshKit.bevel_box(Vector3.ONE * S, 0.06, top, side),
				_library.get_material("lapis_block" if pushable else "lapis_block_dark",
					Color(0.14, 0.4, 0.95) if pushable else Color(0.1, 0.24, 0.6), 0.0, 1.0, 0.15, 0.3)])
			var gold := _library.glow("piece_gold", GOLD, 1.4)
			for y: float in [S * 0.5 - 0.14, -S * 0.5 + 0.14]:
				MeshKit.append_bevel_box(_tool(decor, gold), Vector3(0, y, 0), Vector3(S + 0.012, 0.045, S + 0.012), 0.0,
					Color.WHITE, Color.WHITE)
		WorldTheme.Style.NEON:
			# A dark tech cube traced in light.
			parts.append([MeshKit.bevel_box(Vector3.ONE * S, 0.04, top, side),
				_library.get_material("neon_block" if pushable else "neon_block_dark",
					Color(0.8, 0.85, 0.95) if pushable else Color(0.5, 0.54, 0.64), 0.0, 1.0, 0.3, 0.35)])
			var line := _library.glow("piece_neon", NEON_TEAL if pushable else NEON_MAGENTA, 1.8)
			_edge_frame(_tool(decor, line), S * 0.5 + 0.004, 0.022)
		WorldTheme.Style.VOID:
			# Obsidian split by glowing cracks.
			parts.append([MeshKit.bevel_box(Vector3.ONE * S, 0.08, top, side),
				_library.pbr("castle_wall_slates", Color(0.95, 0.9, 0.98), 1.3, 0.8, 1.0)])
			var lava := _library.glow("piece_lava", LAVA, 1.8)
			for face: int in 4:
				var normal := Vector3(1, 0, 0).rotated(Vector3.UP, face * PI / 2.0)
				var along := normal.cross(Vector3.UP)
				var y := S * 0.5 - 0.06
				var drift := (MeshKit.hash01(face, 1, 97) - 0.5) * 0.3
				for seg: int in 4:
					var length := 0.17
					var at := normal * (S * 0.5 + 0.004) + along * drift + Vector3(0, y - length * 0.5, 0)
					var size := Vector3(0.012, length, 0.035) if absf(normal.x) > 0.5 else Vector3(0.035, length, 0.012)
					MeshKit.append_bevel_box(_tool(decor, lava), at, size, 0.0, Color.WHITE, Color.WHITE)
					drift += (MeshKit.hash01(face, seg, 98) - 0.5) * 0.16
					y -= length
		_:
			# A hewn stone block, its corners inlaid with light, with moss creeping over one edge.
			parts.append([MeshKit.bevel_box(Vector3.ONE * S, 0.09, top, side),
				_library.pbr("castle_wall_slates", Color(1.25, 1.18, 1.0), 1.3, 1.0, 1.0)])
			var light := _library.glow("block_edge", Color("#CFE6FF"), 1.3)
			for corner: Vector2 in _corners():
				var c := corner * (S * 0.5 - 0.005)
				MeshKit.append_bevel_box(_tool(decor, light), Vector3(c.x, 0, c.y), Vector3(0.035, S * 0.8, 0.035), 0.0,
					Color.WHITE, Color.WHITE)
			if _theme.foliage.a > 0.0:
				var moss := _library.pbr("mossy_rock", Color(0.55, 0.85, 0.45), 1.5, 1.0, 1.0)
				MeshKit.append_bevel_box(_tool(decor, moss), Vector3(-S * 0.2, S * 0.5 + 0.012, S * 0.24),
					Vector3(S * 0.5, 0.035, S * 0.36), 0.015, Color.WHITE, Color(0.8, 0.8, 0.8))
	for material: Material in decor.keys():
		parts.append([_commit(decor[material], material), material])
	return parts


## The universal "this block can be pushed" cue: a cyan diamond frame on top.
func _push_mark() -> Mesh:
	if not _parts.has("push_mark"):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y := S * 0.5 + 0.012
		var r := 0.2
		for i: int in 4:
			var a := Vector3(r, 0, 0).rotated(Vector3.UP, i * PI / 2.0)
			var b := Vector3(r, 0, 0).rotated(Vector3.UP, (i + 1) * PI / 2.0)
			var mid := (a + b) * 0.5
			var length := a.distance_to(b)
			var basis := Basis(Vector3.UP, atan2(-(b - a).z, (b - a).x))
			var box := BoxMesh.new()
			box.size = Vector3(length + 0.03, 0.014, 0.035)
			tool.append_from(box, 0, Transform3D(basis, mid + Vector3(0, y, 0)))
		_parts["push_mark"] = tool.commit()
	return _parts["push_mark"]


# --- Gates --------------------------------------------------------------------------

## A gate for this world in `color` (amber, or pink when inverted). The root mesh is centred on the
## gate's box (GATE_SIZE wide, MechanismFixtures3D.GATE_HEIGHT tall), so the fixture code can raise
## and sink it the same way in every world.
func gate(color: Color, inverted: bool) -> MeshInstance3D:
	var key := "gate_%s" % inverted
	if not _parts.has(key):
		_parts[key] = _gate_parts(color, inverted)
	return _assemble(_parts[key], true)


func _gate_parts(color: Color, inverted: bool) -> Array:
	var h := MechanismFixtures3D.GATE_HEIGHT
	var suffix := "_inverted" if inverted else ""
	var band := _library.glow("gate_band" + suffix, color, 1.5)
	var parts: Array = []
	var decor := {}
	match _theme.style:
		WorldTheme.Style.FROST:
			# A wall of ice spikes, frozen in the gate's colour.
			var ice: StandardMaterial3D = _library.get_material("gate_ice" + suffix, color.darkened(0.3), 0.12, 0.95, 0.1, 0.25)
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var spots: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0.22, 0, 0.2), Vector3(-0.24, 0, 0.16),
				Vector3(0.2, 0, -0.22), Vector3(-0.2, 0, -0.24)]
			for i: int in spots.size():
				var tall := h * (1.0 if i == 0 else 0.62 + MeshKit.hash01(i, 2, 99) * 0.3)
				var lean := Vector3(spots[i].x * 0.35, 0, spots[i].z * 0.35)
				MeshKit.append_cone(tool, spots[i] + Vector3(0, -h * 0.5, 0), spots[i] + lean + Vector3(0, -h * 0.5 + tall, 0),
					0.2 if i == 0 else 0.15, Color.WHITE, 6)
			parts.append([_commit(tool, ice), ice])
			MeshKit.append_torus(_tool(decor, band), Vector3(0, -h * 0.5 + 0.06, 0), Vector3.UP, 0.38, 0.025, Color.WHITE, 6, 4)
		WorldTheme.Style.PORTAL, WorldTheme.Style.NEON:
			# An energy barrier between four posts.
			var post := _library.pbr("blue_metal_plate", Color(0.4, 0.4, 0.5), 1.0, 0.7, 0.4, 1.0, false)
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for corner: Vector2 in _corners():
				var c := corner * (GATE_SIZE * 0.5 - 0.05)
				MeshKit.append_bevel_box(tool, Vector3(c.x, 0, c.y), Vector3(0.1, h, 0.1), 0.02, Color.WHITE, Color.WHITE)
			parts.append([_commit(tool, post), post])
			var field := _library.glow("gate_field" + suffix, color, 1.0, 0.55)
			MeshKit.append_bevel_box(_tool(decor, field), Vector3(0, -0.02, 0), Vector3(GATE_SIZE - 0.14, h - 0.08, GATE_SIZE - 0.14),
				0.0, Color.WHITE, Color.WHITE)
			_ring(_tool(decor, band), h * 0.5 + 0.005, GATE_SIZE * 0.5 - 0.05, 0.03)
			_ring(_tool(decor, band), 0.0, GATE_SIZE * 0.5 - 0.045, 0.02)
		_:
			# A heavy door of the world's own material, banded in the gate's colour.
			var body: StandardMaterial3D
			match _theme.style:
				WorldTheme.Style.FOUNDRY:
					body = _library.pbr("rusty_metal_02", color.lerp(Color.WHITE, 0.15), 1.2, 0.9, 0.35)
				WorldTheme.Style.TEMPLE:
					body = _library.pbr("marble_01", color.lerp(Color.WHITE, 0.45), 1.2, 0.6, 1.0)
				WorldTheme.Style.VOID:
					body = _library.pbr("castle_wall_slates", color.lerp(Color.WHITE, 0.1), 1.3, 0.8, 1.0)
				_:
					body = _library.pbr("castle_wall_slates", color.lerp(Color.WHITE, 0.25), 1.3, 1.0, 1.0)
			parts.append([MeshKit.bevel_box(Vector3(GATE_SIZE, h, GATE_SIZE), 0.06, Color(1, 1, 1), Color(0.78, 0.78, 0.78)), body])
			MeshKit.append_bevel_box(_tool(decor, band), Vector3(0, 0.16, 0), Vector3(GATE_SIZE + 0.012, 0.04, GATE_SIZE + 0.012),
				0.0, Color.WHITE, Color.WHITE)
			if _theme.style == WorldTheme.Style.FOUNDRY or _theme.style == WorldTheme.Style.VOID:
				MeshKit.append_bevel_box(_tool(decor, band), Vector3(0, -0.12, 0), Vector3(GATE_SIZE + 0.012, 0.04, GATE_SIZE + 0.012),
					0.0, Color.WHITE, Color.WHITE)
			var cap := Basis(Vector3.UP, PI / 4.0)
			var cap_box := BoxMesh.new()
			cap_box.size = Vector3(0.26, 0.02, 0.26)
			var cap_tool := SurfaceTool.new()
			cap_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			cap_tool.append_from(cap_box, 0, Transform3D(cap, Vector3(0, h * 0.5 + 0.005, 0)))
			var cap_material := _library.glow("gate_cap" + suffix, color, 1.0)
			parts.append([cap_tool.commit(), cap_material])
	for material: Material in decor.keys():
		parts.append([_commit(decor[material], material), material])
	return parts


# --- Core ---------------------------------------------------------------------------

## The core's crystal for this world: [outer mesh, heart mesh]. Always cyan; only the cut differs.
func core_meshes() -> Array[Mesh]:
	match _theme.style:
		WorldTheme.Style.FROST:
			return [_bipyramid(0.2, 0.46, 6), MeshKit.octahedron(0.09, 0.2)]
		WorldTheme.Style.FOUNDRY:
			return [_bipyramid(0.3, 0.3, 8), MeshKit.octahedron(0.13, 0.13)]
		WorldTheme.Style.NEON:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * 0.4
			var heart := BoxMesh.new()
			heart.size = Vector3.ONE * 0.17
			return [cube, heart]
		WorldTheme.Style.VOID, WorldTheme.Style.PORTAL:
			return [_bipyramid(0.26, 0.42, 4, true), MeshKit.octahedron(0.11, 0.18)]
	return [MeshKit.octahedron(0.28, 0.4), MeshKit.octahedron(0.12, 0.18)]


## Two cones base to base; `star` adds a second, turned pair for an eight-pointed cut.
static func _bipyramid(radius: float, half_height: float, sides: int, star: bool = false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for turn: int in (2 if star else 1):
		var ring := PackedVector3Array()
		for i: int in sides:
			var angle := TAU * i / sides + turn * PI / sides
			ring.append(Vector3(cos(angle), 0, sin(angle)) * radius * (1.0 if turn == 0 else 0.8))
		for i: int in sides:
			var a := ring[i]
			var b := ring[(i + 1) % sides]
			MeshKit.triangle(tool, a, b, Vector3(0, half_height, 0), Color.WHITE, (a + b) * 0.5 + Vector3.UP * 0.2)
			MeshKit.triangle(tool, a, b, Vector3(0, -half_height, 0), Color.WHITE, (a + b) * 0.5 + Vector3.DOWN * 0.2)
	return tool.commit()


# --- Helpers ------------------------------------------------------------------------

static func _corners() -> Array[Vector2]:
	return [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]


## Thin bars along all twelve edges of a cube of half-size `half`.
static func _edge_frame(tool: SurfaceTool, half: float, thickness: float) -> void:
	for axis: int in 3:
		for u: float in [-1.0, 1.0]:
			for v: float in [-1.0, 1.0]:
				var centre := Vector3.ZERO
				var size := Vector3.ONE * thickness
				centre[(axis + 1) % 3] = u * half
				centre[(axis + 2) % 3] = v * half
				size[axis] = half * 2.0
				MeshKit.append_bevel_box(tool, centre, size, 0.0, Color.WHITE, Color.WHITE)


## A square ring of bars at height `y`.
static func _ring(tool: SurfaceTool, y: float, half: float, thickness: float) -> void:
	for side: int in 4:
		var along_x := side < 2
		var sign := -1.0 if side % 2 == 0 else 1.0
		var centre := Vector3(0, y, sign * half) if along_x else Vector3(sign * half, y, 0)
		var size := Vector3(half * 2.0 + thickness, thickness, thickness) if along_x \
			else Vector3(thickness, thickness, half * 2.0 + thickness)
		MeshKit.append_bevel_box(tool, centre, size, 0.0, Color.WHITE, Color.WHITE)


static func _tool(tools: Dictionary, material: Material) -> SurfaceTool:
	if not tools.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[material] = tool
	return tools[material]


static func _commit(tool: SurfaceTool, material: Material) -> ArrayMesh:
	var mesh := tool.commit()
	return MeshKit.normalize_shades(mesh) if MeshKit.is_shaded_pbr(material) else mesh


## The first part becomes the root (it casts the shadow); the rest hang under it.
func _assemble(parts: Array, shadow: bool) -> MeshInstance3D:
	var root := MeshInstance3D.new()
	root.mesh = parts[0][0]
	if MeshKit.is_shaded_pbr(parts[0][1]) and root.mesh is ArrayMesh:
		root.mesh = MeshKit.normalize_shades(root.mesh as ArrayMesh)
		parts[0][0] = root.mesh
	root.material_override = parts[0][1]
	if not shadow:
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i: int in range(1, parts.size()):
		_add_part(root, parts[i][0], parts[i][1], false)
	return root


static func _add_part(parent: Node3D, mesh: Mesh, material: Material, shadow: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	if not shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
