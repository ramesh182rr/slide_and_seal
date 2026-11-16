class_name IslandDecor
extends Node3D
## The world around the board (docs/06 §1, docs/07 world themes): what the board stands on and
## what surrounds it, built per WorldTheme.Style from code. Pure scenery: it sits below and around
## the board, never on a cell, so nothing here can be mistaken for something interactive
## (docs/05 §4). Idle motion (drifting fragments, a turning seal ring) is presentation only.
##
## Cost: static scenery is merged into one mesh per material (a handful of draw calls per world).
## Tall pieces (chamber walls, pillars, portals) register the direction they stand in; pieces on
## the camera's side are hidden so they never block the board (set_view_yaw).

const DRIFT_AMPLITUDE := 0.08
const DRIFT_SPEED := 0.6
## Hide a tall piece when its outward direction points this much towards the camera.
const CUTAWAY_DOT := 0.35

var animate := true

var _theme: WorldTheme
var _library: MaterialLibrary
var _centre := Vector3.ZERO
## Half extents of the board's cell area (x, z) in world units.
var _board_half := Vector2.ZERO
var _fragments: Array[Node3D] = []
var _rest: Array[float] = []
var _spinners: Array[Node3D] = []
var _time := 0.0
## Batches for the node being built: material → SurfaceTool.
var _tools: Dictionary = {}
## [node, outward direction (x, z)] for cutaway.
var _tall: Array[Array] = []
var _view_yaw := 45.0


func build(board_size: Vector2i, theme: WorldTheme, library: MaterialLibrary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_fragments.clear()
	_rest.clear()
	_spinners.clear()
	_tall.clear()
	_theme = theme
	_library = library
	_centre = BoardCoords.board_center(board_size)
	_board_half = Vector2(board_size.x, board_size.y) * 0.5 * BoardCoords.CELL_SIZE
	# Every world is the arena of a colossal maze (M17), built from its own materials; some add
	# their landmark pieces inside the courtyard.
	_build_arena()
	match theme.style:
		WorldTheme.Style.FOUNDRY:
			_build_foundry()
		WorldTheme.Style.PORTAL:
			_build_portals()
		WorldTheme.Style.TEMPLE:
			_build_temple()
	_build_fragments()
	set_view_yaw(_view_yaw)


func _process(delta: float) -> void:
	if not animate:
		return
	_time += delta
	for i: int in _fragments.size():
		_fragments[i].position.y = _rest[i] + sin(_time * DRIFT_SPEED + i * 1.7) * DRIFT_AMPLITUDE
	for spinner: Node3D in _spinners:
		spinner.rotate_y(delta * 0.15)


func fragment_count() -> int:
	return _fragments.size()


## Hides tall scenery between the camera and the board. `yaw_degrees` is the camera's yaw about
## the board (CameraRig convention: the camera sits at (sin yaw, cos yaw) from the centre).
func set_view_yaw(yaw_degrees: float) -> void:
	_view_yaw = yaw_degrees
	var toward_camera := Vector2(sin(deg_to_rad(yaw_degrees)), cos(deg_to_rad(yaw_degrees)))
	for entry: Array in _tall:
		var direction: Vector2 = entry[1]
		(entry[0] as Node3D).visible = direction.normalized().dot(toward_camera) < CUTAWAY_DOT


func visible_tall_count() -> int:
	var count := 0
	for entry: Array in _tall:
		if (entry[0] as Node3D).visible:
			count += 1
	return count


# --- Styles -----------------------------------------------------------------------

## The scanned boulder, turned upside down and fitted under the board: top at `top_y`, footprint
## `half` (x, z), `depth` deep.
func _hang_boulder(half: Vector2, depth: float, top_y: float) -> void:
	var boulder := ModelLibrary.mesh("boulder_01")
	if boulder == null:
		return
	var box := boulder.get_aabb()
	var scale := Vector3(half.x * 2.0 / box.size.x, depth / box.size.y, half.y * 2.0 / box.size.z)
	var node := _mesh(boulder, ModelLibrary.material(_library, "boulder_01", _theme.rock_model_tint), Vector3.ZERO)
	node.name = "Boulder"
	node.basis = Basis(Vector3.RIGHT, PI).scaled(scale)
	# Flipped about X: y → -y·sy and z → -z·sz.
	node.position = Vector3(_centre.x - (box.position.x + box.size.x * 0.5) * scale.x,
		top_y + box.position.y * scale.y,
		_centre.z + (box.position.z + box.size.z * 0.5) * scale.z)


## The arena of a colossal maze, in this world's materials. Towering wall panels with dark seams
## and a cast ledge ring a paved courtyard; the two walls the default view faces each hold a great
## door standing ajar with light behind it. Each world dresses its walls differently (ivy, icicles,
## pipes, runes, gold, neon, lava). Walls on the camera's side are cut away (named Wall_0..3:
## -z, +z, -x, +x). The courtyard rests on rock and the scanned boulder, so the arena floats.
func _build_arena() -> void:
	var style := _theme.style
	var margin := 1.3
	var half := _board_half + Vector2(margin, margin)
	var height := 6.0
	var thickness := 1.1
	var wall: StandardMaterial3D
	var court: StandardMaterial3D
	var door_light := Color("#FFE2A6")
	match style:
		WorldTheme.Style.FROST:
			wall = _library.pbr("castle_wall_slates", Color(0.5, 0.68, 0.9), 0.5, 0.5, 1.0)
			court = _library.pbr("snow_02", Color(0.3, 0.4, 0.6), 0.5, 0.6, 1.0)
			door_light = Color("#9FE8FF")
		WorldTheme.Style.FOUNDRY:
			wall = _library.pbr("rusty_metal_02", Color(0.42, 0.38, 0.36), 0.35, 0.9, 0.4)
			court = _library.pbr("metal_plate", Color(0.55, 0.5, 0.46), 0.6, 0.9, 0.25)
			door_light = Color("#FF8A2A")
		WorldTheme.Style.PORTAL:
			wall = _library.pbr("castle_wall_slates", Color(0.4, 0.34, 0.6), 0.5, 1.0, 1.0)
			court = _library.pbr("marble_01", Color(0.26, 0.22, 0.42), 0.4, 0.8, 1.0)
			door_light = Color("#C9A8FF")
		WorldTheme.Style.TEMPLE:
			wall = _library.pbr("castle_wall_slates", Color(0.86, 0.76, 0.58), 0.5, 1.0, 1.0)
			court = _library.pbr("marble_01", Color(0.6, 0.55, 0.46), 0.4, 0.8, 1.0)
			door_light = Color("#FFD98A")
		WorldTheme.Style.NEON:
			wall = _library.pbr("blue_metal_plate", Color(0.3, 0.3, 0.42), 0.35, 0.8, 0.4)
			court = _library.pbr("blue_metal_plate", Color(0.2, 0.2, 0.3), 0.45, 0.8, 0.4)
			door_light = Color("#FF3FA0")
		WorldTheme.Style.VOID:
			wall = _library.pbr("dark_rock", Color(0.62, 0.62, 0.7), 0.4, 0.8, 1.0)
			court = _library.pbr("dark_rock", Color(0.4, 0.4, 0.46), 0.5, 0.9, 1.0)
			door_light = Color("#FF8A2A")
		_:
			# Cool grey weathered concrete (the scan is warm; the tint takes the yellow out).
			wall = _library.pbr("concrete_moss", Color(0.5, 0.6, 0.66), 0.45, 1.0, 1.0)
			court = _library.pbr("overgrown_concrete_pavers", Color(0.42, 0.52, 0.5), 0.5, 1.0, 1.0)
	_begin()
	MeshKit.append_bevel_box(_tool(court), _centre + Vector3(0, -0.5, 0),
		Vector3(half.x * 2.0 + thickness * 2.0, 0.5, half.y * 2.0 + thickness * 2.0), 0.08, Color.WHITE, Color(0.6, 0.6, 0.6))
	_flush(self, "Courtyard")
	var rim := half + Vector2(thickness + 0.3, thickness + 0.3)
	_mesh(MeshKit.normalize_shades(MeshKit.rock_island(rim, 2.0, 11, _theme.rock,
		_theme.stone_dark.lerp(_theme.foliage, _theme.foliage.a * 0.5), 36)), _rock(), _centre + Vector3(0, -0.74, 0))
	_hang_boulder(rim * 0.92, maxf(rim.x, rim.y) * 1.3 + 2.5, -1.2)
	var light := _library.glow("arena_door_light", door_light, 1.2)
	for side: int in 4:
		var along_x := side < 2
		var sign := -1.0 if side % 2 == 0 else 1.0
		var outward := Vector2(0, sign) if along_x else Vector2(sign, 0)
		var length := (half.x if along_x else half.y) * 2.0 + thickness * 2.0
		var base := _centre + Vector3(outward.x * (half.x + thickness * 0.5), -0.25, outward.y * (half.y + thickness * 0.5))
		var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var inward := Vector3(-outward.x, 0, -outward.y)
		var face := base + inward * (thickness * 0.5 + 0.03)
		var node := Node3D.new()
		node.name = "Wall_%d" % side
		add_child(node)
		_begin()
		var count := maxi(3, int(round(length / 2.2)))
		var width := length / count
		var door := side == 0 or side == 2  # The two walls the default view faces.
		for k: int in count:
			var t := -length * 0.5 + (k + 0.5) * width
			var tall := height * (0.92 + MeshKit.hash01(side, k, 111) * 0.16)
			var panel_width := width - 0.07
			if door and k == count / 2:
				# Two door leaves standing ajar, with a slot of light between them.
				for leaf: float in [-1.0, 1.0]:
					var leaf_w := panel_width * 0.36
					MeshKit.append_bevel_box(_tool(wall), base + along * (t + leaf * (panel_width * 0.5 - leaf_w * 0.5))
						+ Vector3(0, tall * 0.5, 0), (Vector3(leaf_w, tall, thickness * 0.8) if along_x else Vector3(thickness * 0.8, tall, leaf_w)),
						0.06, Color(0.8, 0.8, 0.8), Color(0.62, 0.62, 0.62), Vector2(k * 3.1, side * 1.7))
				MeshKit.append_bevel_box(_tool(light), base + along * t + Vector3(0, tall * 0.45, 0),
					(Vector3(panel_width * 0.28, tall * 0.9, 0.05) if along_x else Vector3(0.05, tall * 0.9, panel_width * 0.28)), 0.0,
					Color.WHITE, Color.WHITE)
				continue
			MeshKit.append_bevel_box(_tool(wall), base + along * t + Vector3(0, tall * 0.5, 0),
				(Vector3(panel_width, tall, thickness) if along_x else Vector3(thickness, tall, panel_width)), 0.08,
				Color.WHITE, Color(0.74, 0.74, 0.74), Vector2(k * 3.1, side * 1.7))
			# A ledge near the top, like cast formwork.
			MeshKit.append_bevel_box(_tool(wall), base + along * t + Vector3(0, tall - 0.5, 0) + inward * 0.04,
				(Vector3(panel_width, 0.22, thickness + 0.1) if along_x else Vector3(thickness + 0.1, 0.22, panel_width)), 0.04,
				Color(0.9, 0.9, 0.9), Color(0.66, 0.66, 0.66))
			_dress_panel(style, side, k, face + along * t, along, inward, panel_width, tall)
		_flush(node, "WallMesh")
		_tall.append([node, outward])


## One wall panel's dressing. `at` is the foot of the panel's inner face, `along` runs across it.
func _dress_panel(style: WorldTheme.Style, side: int, k: int, at: Vector3, along: Vector3, inward: Vector3,
		width: float, tall: float) -> void:
	var along_x := absf(along.x) > 0.5
	var key := side * 64 + k
	match style:
		WorldTheme.Style.FROST:
			# Snow on the top, icicles under the ledge, and now and then a frozen fall of light.
			var snow := _library.pbr("snow_02", Color(0.95, 0.98, 1.0), 0.6, 1.0, 1.0)
			MeshKit.append_bevel_box(_tool(snow), at - inward * 0.55 + Vector3(0, tall + 0.07, 0),
				(Vector3(width, 0.16, 1.2) if along_x else Vector3(1.2, 0.16, width)), 0.06, Color.WHITE, Color(0.85, 0.85, 0.85))
			var icicle := _crystal_material(Color("#BFE6FF"), 0.5, 0.85)
			var steps := int(width / 0.3)
			for n: int in steps:
				if MeshKit.hash01(key, n, 69) < 0.3:
					continue
				var drop := 0.3 + MeshKit.hash01(key, n, 70) * 0.9
				var top := at + along * (-width * 0.5 + (n + 0.5) * 0.3) + Vector3(0, tall - 0.6, 0) + inward * 0.08
				MeshKit.append_cone(_tool(icicle), top, top + Vector3(0, -drop, 0), 0.05 + drop * 0.04, Color.WHITE, 5)
			if MeshKit.hash01(side, k, 71) < 0.35:
				var fall := _library.glow("frost_fall", Color("#8FE0FF"), 1.1, 0.35)
				MeshKit.append_bevel_box(_tool(fall), at + Vector3(0, tall * 0.45, 0),
					(Vector3(0.5, tall * 0.9, 0.02) if along_x else Vector3(0.02, tall * 0.9, 0.5)), 0.0, Color.WHITE, Color.WHITE)
		WorldTheme.Style.FOUNDRY:
			# Pipes with flanges run along the wall; a hot vent glows in every panel.
			var metal := _library.surface_spec(_theme.metal_surface)
			var hot := _library.glow("foundry_hot", Color("#FF7A1A"), 2.2)
			for p: int in 2:
				var y := tall * (0.3 + p * 0.28)
				var radius := 0.13 - p * 0.03
				var centre := at + Vector3(0, y, 0) + inward * (radius + 0.02)
				MeshKit.append_cylinder(_tool(metal), centre - along * (width * 0.5 + 0.04), centre + along * (width * 0.5 + 0.04),
					radius, Color(0.7, 0.7, 0.7), 8, false)
				MeshKit.append_cylinder(_tool(metal), centre - along * 0.06, centre + along * 0.06, radius + 0.05, Color.WHITE, 8)
			MeshKit.append_bevel_box(_tool(hot), at + Vector3(0, tall * 0.14, 0),
				(Vector3(width * 0.5, 0.14, 0.02) if along_x else Vector3(0.02, 0.14, width * 0.5)), 0.0, Color.WHITE, Color.WHITE)
		WorldTheme.Style.PORTAL:
			# A glowing rune strip down each panel, with crystals growing from its foot.
			var rune := _library.glow("portal_ring", Palette.PORTAL_VIOLET, 2.0)
			var y := tall * 0.9
			while y > tall * 0.25:
				var seg := 0.3 + MeshKit.hash01(key, int(y * 10.0), 72) * 0.5
				MeshKit.append_bevel_box(_tool(rune), at + Vector3(0, y - seg * 0.5, 0),
					(Vector3(0.07, seg, 0.02) if along_x else Vector3(0.02, seg, 0.07)), 0.0, Color.WHITE, Color.WHITE)
				y -= seg + 0.14
		WorldTheme.Style.TEMPLE:
			# Bands of gold.
			var gold := _library.glow("temple_gold", Color("#F2C46A"), 1.6)
			for y: float in [tall * 0.2, tall * 0.74]:
				MeshKit.append_bevel_box(_tool(gold), at + Vector3(0, y, 0),
					(Vector3(width, 0.09, 0.02) if along_x else Vector3(0.02, 0.09, width)), 0.0, Color.WHITE, Color.WHITE)
		WorldTheme.Style.NEON:
			# Strips of neon, teal and magenta.
			var strip := _library.glow("neon_teal", Color("#3FF2E0"), 2.0) if k % 3 != 0 \
				else _library.glow("neon_magenta", Color("#FF3FA0"), 2.0)
			MeshKit.append_bevel_box(_tool(strip), at + Vector3(0, tall * 0.5, 0),
				(Vector3(0.07, tall * 0.94, 0.02) if along_x else Vector3(0.02, tall * 0.94, 0.07)), 0.0, Color.WHITE, Color.WHITE)
			MeshKit.append_bevel_box(_tool(strip), at + Vector3(0, tall * 0.62, 0),
				(Vector3(width * 0.7, 0.05, 0.02) if along_x else Vector3(0.02, 0.05, width * 0.7)), 0.0, Color.WHITE, Color.WHITE)
		WorldTheme.Style.VOID:
			# Glowing cracks split the stone.
			var vein := _library.glow("void_vein", Color("#FF8A2A"), 2.0)
			for c: int in 2:
				var drift := (MeshKit.hash01(key, c, 81) - 0.5) * width * 0.6
				var y := tall * (0.95 - c * 0.2)
				while y > tall * 0.15:
					var seg := 0.3 + MeshKit.hash01(key, c * 13 + int(y * 10.0), 82) * 0.4
					MeshKit.append_bevel_box(_tool(vein), at + along * drift + Vector3(0, y - seg * 0.5, 0),
						(Vector3(0.05, seg, 0.02) if along_x else Vector3(0.02, seg, 0.05)), 0.0, Color.WHITE, Color.WHITE)
					drift += (MeshKit.hash01(key, c * 7 + int(y * 10.0), 83) - 0.5) * 0.3
					y -= seg
		_:
			# Ivy: a drift of leaves spilling down from the top of most panels, and hanging vines.
			if MeshKit.hash01(side, k, 112) >= 0.7:
				return
			var leaf_a := _library.get_material("ivy_leaf", Color(0.2, 0.42, 0.16), 0.0, 1.0, 0.0, 0.7)
			var leaf_b := _library.get_material("ivy_leaf_light", Color(0.34, 0.56, 0.22), 0.0, 1.0, 0.0, 0.7)
			var vine := _library.get_material("ivy_vine", Color(0.16, 0.22, 0.1), 0.0, 1.0, 0.0, 0.9)
			var reach := tall * (0.35 + MeshKit.hash01(side, k, 113) * 0.5)
			for n: int in int(reach * 34.0):
				var fall := pow(MeshKit.hash01(key, n, 114), 1.6) * reach
				var spread := width * 0.5 * (1.0 - fall / reach * 0.55)
				var across := (MeshKit.hash01(key, n, 115) - 0.5) * 2.0 * spread
				var centre := at + along * across + Vector3(0, tall - 0.1 - fall, 0) + inward * MeshKit.hash01(n, k, 116) * 0.06
				var size := 0.1 + MeshKit.hash01(n, side, 117) * 0.1
				var tilt := (MeshKit.hash01(n, k, 118) - 0.5) * 1.2
				var up := (Vector3.UP * cos(tilt) + along * sin(tilt)) * size
				var across_vec := along.rotated(inward, tilt) * size * 0.8
				var material: Material = leaf_a if MeshKit.hash01(n, k, 119) < 0.6 else leaf_b
				MeshKit.quad(_tool(material), centre - across_vec - up, centre + across_vec - up, centre + across_vec + up,
					centre - across_vec + up, inward, Color.WHITE, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
			for v: int in 3:
				var x := (MeshKit.hash01(side * 8 + k, v, 120) - 0.5) * width * 0.8
				var drop := reach * (0.6 + MeshKit.hash01(side * 8 + k, v, 121) * 0.6)
				var top := at + along * x + Vector3(0, tall - 0.05, 0) + inward * 0.03
				MeshKit.append_cylinder(_tool(vine), top, top + Vector3(0, -drop, 0), 0.018, Color.WHITE, 4, false)


## World 3's landmarks inside the arena: pressure tanks and stacked barrels at the courtyard
## corners, and the glow of lava far below.
func _build_foundry() -> void:
	var metal := _surface("foundry_metal", 0.45, 0.6)
	var hot := _library.glow("foundry_hot", Color("#FF7A1A"), 2.2)
	var beam_color := Color("#3A3C42")
	var pipe_color := Color("#55524E")
	var half := _board_half
	# Pressure tanks at the corners (tall: cut away on the camera's side).
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var node := Node3D.new()
		node.name = "Tank"
		add_child(node)
		_begin()
		var at := _centre + Vector3(corner.x * (half.x + 0.75), -0.25, corner.y * (half.y + 0.75))
		MeshKit.append_cylinder(_tool(metal), at, at + Vector3(0, 1.9, 0), 0.5, pipe_color, 12)
		MeshKit.append_cylinder(_tool(metal), at + Vector3(0, 1.9, 0), at + Vector3(0, 2.15, 0), 0.32, pipe_color.lightened(0.2), 12)
		MeshKit.append_cylinder(_tool(hot), at + Vector3(0, 1.0, 0), at + Vector3(0, 1.18, 0), 0.51, Color.WHITE, 12, false)
		MeshKit.append_cylinder(_tool(hot), at + Vector3(0, 2.15, 0), at + Vector3(0, 2.2, 0), 0.12, Color.WHITE, 8)
		_flush(node, "TankMesh")
		_tall.append([node, corner])
	# Barrels stacked at the deck corners (scanned CC0 models), cut away on the camera's side.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var node := Node3D.new()
		node.name = "Barrels"
		add_child(node)
		for k: int in 3:
			var model := "Barrel_01" if (k + int(corner.x + 2)) % 2 == 0 else "barrel_03"
			var barrel := ModelLibrary.mesh(model)
			if barrel == null:
				continue
			var along := Vector3(-corner.x, 0, 0) if k == 1 else Vector3(0, 0, -corner.y)
			var at := _centre + Vector3(corner.x * (half.x + 0.3), -0.25, corner.y * (half.y + 0.3)) + along * (0.0 if k == 0 else 0.55)
			var instance := _mesh(barrel, ModelLibrary.material(_library, model, Color(0.85, 0.8, 0.75)), Vector3.ZERO, node)
			var box := barrel.get_aabb()
			var scale := 0.5 / box.size.y
			instance.scale = Vector3.ONE * scale
			instance.rotation.y = MeshKit.hash01(k, int(corner.x * 3 + corner.y), 91) * TAU
			instance.position = at - Vector3(0, box.position.y * scale, 0)
		_tall.append([node, corner])

	# The lava below: a glowing pool that fades out at its edges (additive, so it melts into the
	# sky instead of ending in a hard rectangle), plus a brighter core under the deck.
	for layer: int in 2:
		var pool := QuadMesh.new()
		pool.orientation = PlaneMesh.FACE_Y
		pool.size = Vector2.ONE * maxf(half.x, half.y) * (7.0 if layer == 0 else 3.5)
		var lava := _library.glow("lava_pool_%d" % layer, Color("#FF5A10"), 1.1 if layer == 0 else 1.6)
		if lava.albedo_texture == null:
			lava.albedo_texture = BoardRenderer3D.radial_texture()
			lava.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lava.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mesh(pool, lava, _centre + Vector3(0, -8.0 + layer * 0.05, 0))


## World 4: an island ringed by standing portal gates.
func _build_portals() -> void:
	var stone := _rock()
	var ring := _library.glow("portal_ring", Palette.PORTAL_VIOLET, 2.0)
	var veil := _library.glow("portal_veil", Palette.PORTAL_VIOLET, 0.8, 0.25)
	# Mid-edge, so the two on the far side stay on screen on narrow phones.
	var h := _board_half + Vector2(0.9, 0.9)
	var spots: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i: int in spots.size():
		var corner := spots[i]
		var node := Node3D.new()
		node.name = "Portal"
		add_child(node)
		_begin()
		var at := _centre + Vector3(corner.x * h.x, -0.25, corner.y * h.y)
		var facing := Vector3(-corner.x, 0, -corner.y).normalized()
		var side := facing.cross(Vector3.UP)
		MeshKit.append_bevel_box(_tool(stone), at + Vector3(0, 0.15, 0), Vector3(1.2, 0.3, 1.2), 0.06,
			_theme.stone, _theme.stone_dark)
		var centre := at + Vector3(0, 1.4, 0)
		MeshKit.append_torus(_tool(ring), centre, facing, 0.95, 0.09, Color.WHITE, 28, 6)
		var disc := CylinderMesh.new()
		disc.top_radius = 0.9
		disc.bottom_radius = 0.9
		disc.height = 0.02
		disc.radial_segments = 24
		(_tool(veil)).append_from(disc, 0, Transform3D(Basis(Quaternion(Vector3.UP, facing)), centre))
		for s: float in [-1.0, 1.0]:
			MeshKit.append_cylinder(_tool(stone), at + Vector3(0, 0.3, 0) + side * s * 0.95,
				centre + side * s * 0.95 + Vector3(0, -0.3, 0), 0.1, _theme.stone_dark, 6)
		_flush(node, "PortalMesh")
		_tall.append([node, corner])


## World 5: a temple island with gold-capped pillars and a great seal ring turning beneath it.
func _build_temple() -> void:
	var stone := _surface("temple_stone", 0.7)
	var gold := _library.glow("temple_gold", Color("#F2C46A"), 1.6)
	var h := _board_half + Vector2(0.45, 0.45)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var node := Node3D.new()
		node.name = "Column"
		add_child(node)
		_begin()
		var at := _centre + Vector3(corner.x * h.x, -0.25, corner.y * h.y)
		_column(node, at, 0.7, _library.pbr("marble_01", Color(0.92, 0.9, 0.86), 1.0, 0.7, 1.0, 1.0, false))
		MeshKit.append_cylinder(_tool(gold), at + Vector3(0, 2.52, 0), at + Vector3(0, 2.56, 0), 0.31, Color.WHITE, 20)
		_flush(node, "ColumnMesh")
		_tall.append([node, corner])
	var spinner := Node3D.new()
	spinner.name = "SealRing"
	spinner.position = _centre + Vector3(0, -2.4, 0)
	add_child(spinner)
	_begin()
	var radius := maxf(_board_half.x, _board_half.y) + 4.4
	MeshKit.append_torus(_tool(gold), Vector3.ZERO, Vector3.UP, radius, 0.06, Color.WHITE, 64, 4)
	MeshKit.append_torus(_tool(gold), Vector3.ZERO, Vector3.UP, radius * 0.86, 0.03, Color.WHITE, 64, 4)
	for k: int in 12:
		var angle := TAU * k / 12.0
		var at := Vector3(cos(angle), 0, sin(angle)) * radius * 0.93
		MeshKit.append_bevel_box(_tool(gold), at, Vector3(0.18, 0.04, 0.18), 0.0, Color.WHITE, Color.WHITE)
	_flush(spinner, "SealRingMesh")
	_spinners.append(spinner)


## Floating pieces around the scene: rock islets, ice shards, tech cubes or debris per style.
func _build_fragments() -> void:
	var outer := _board_half + Vector2(1.8, 1.8)
	var spots: Array[Vector3] = [
		Vector3(-outer.x - 0.4, -2.2, outer.y * 0.2), Vector3(outer.x + 0.3, -3.0, -outer.y * 0.35),
		Vector3(-outer.x * 0.4, -4.4, outer.y + 0.4), Vector3(outer.x * 0.6, -1.8, outer.y + 0.7),
		Vector3(outer.x + 0.1, -4.8, outer.y * 0.7), Vector3(-outer.x + 0.1, -5.4, -outer.y * 0.6),
	]
	for i: int in spots.size():
		var size := 0.45 + MeshKit.hash01(i, 3, 5) * 0.55
		var fragment := Node3D.new()
		fragment.name = "Fragment_%d" % i
		fragment.position = _centre + spots[i]
		add_child(fragment)
		match _theme.style:
			WorldTheme.Style.NEON:
				_begin()
				var body := _surface("neon_body", 0.55, 0.3)
				MeshKit.append_bevel_box(_tool(body), Vector3.ZERO, Vector3.ONE * size, 0.06, _theme.stone_dark.lightened(0.2),
					_theme.stone_dark)
				var glow := _library.glow("neon_magenta" if i % 2 == 0 else "neon_teal",
					Color("#FF3FA0") if i % 2 == 0 else Color("#3FF2E0"), 2.0)
				MeshKit.append_bevel_box(_tool(glow), Vector3(0, size * 0.5 + 0.01, 0), Vector3(size * 0.5, 0.02, size * 0.5), 0.0,
					Color.WHITE, Color.WHITE)
				_flush(fragment, "Cube")
				fragment.rotation = Vector3(MeshKit.hash01(i, 7) * 0.6, MeshKit.hash01(i, 8) * TAU, 0)
			_:
				# Scanned rocks, alternating two shapes, at varied sizes and turns.
				var model := "rock_07" if i % 2 == 0 else "rock_09"
				var rock := ModelLibrary.mesh(model)
				if rock != null:
					var mesh := _mesh(rock, ModelLibrary.material(_library, model, _theme.rock_model_tint), Vector3.ZERO, fragment)
					mesh.rotation = Vector3(MeshKit.hash01(i, 10) * 0.8, MeshKit.hash01(i, 9) * TAU, MeshKit.hash01(i, 11) * 0.6)
					mesh.scale = Vector3.ONE * size * 0.75
				if _theme.crystal.a > 0.0 and i % 2 == 0:
					_crystals(fragment, Vector3.ZERO, 0.5 + size * 0.4, i)
		_fragments.append(fragment)
		_rest.append(fragment.position.y)


# --- Helpers ----------------------------------------------------------------------

## A fluted column (tools/blender/build_props.py, 1 wide × 4 tall) standing at `at`, `width` wide.
func _column(parent: Node3D, at: Vector3, width: float, material: Material) -> void:
	var column := ModelLibrary.mesh("column")
	if column == null:
		return
	var box := column.get_aabb()
	var scale := width / maxf(box.size.x, 0.001)
	var instance := _mesh(column, material, Vector3.ZERO, parent)
	instance.name = "Column"
	instance.scale = Vector3.ONE * scale
	instance.position = at - Vector3(0, box.position.y * scale, 0)

func _rock() -> StandardMaterial3D:
	return _library.surface_spec(_theme.rock_surface)


## Scanned material for a scenery role: metal for machinery, floor stone for the void monolith,
## wall stone (masonry) for everything built.
func _surface(key: String, _roughness: float, _metallic: float = 0.0) -> StandardMaterial3D:
	match key:
		"foundry_metal", "neon_body":
			return _library.surface_spec(_theme.metal_surface)
		"void_stone":
			return _library.surface_spec(_theme.floor_surface)
	return _library.surface_spec(_theme.wall_surface)


func _crystal_material(color: Color, emission: float, alpha: float) -> StandardMaterial3D:
	return _library.crystal("decor_crystal", color, emission, alpha)


func _crystals(parent: Node3D, at: Vector3, scale: float, seed: int) -> void:
	var cluster := _mesh(MeshKit.crystal_cluster(seed, scale), _crystal_material(_theme.crystal, 1.6, 0.9), at, parent)
	cluster.rotation.y = MeshKit.hash01(seed, 2) * TAU


func _begin() -> void:
	_tools.clear()


func _tool(material: Material) -> SurfaceTool:
	if not _tools.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = tool
	return _tools[material]


## One MeshInstance3D per material batched since _begin(), under `parent`. No shadows: scenery.
func _flush(parent: Node3D, base_name: String) -> void:
	var index := 0
	for material: Material in _tools.keys():
		var instance := MeshInstance3D.new()
		instance.name = "%s_%d" % [base_name, index]
		instance.mesh = (_tools[material] as SurfaceTool).commit()
		if MeshKit.is_shaded_pbr(material):
			instance.mesh = MeshKit.normalize_shades(instance.mesh)
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		index += 1
	_tools.clear()


func _mesh(mesh: Mesh, material: Material, at: Vector3, parent: Node = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
