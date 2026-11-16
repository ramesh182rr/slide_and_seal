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
	match theme.style:
		WorldTheme.Style.FROST:
			_build_frost()
		WorldTheme.Style.FOUNDRY:
			_build_foundry()
		WorldTheme.Style.PORTAL:
			_build_island(0.75)
			_build_portals()
		WorldTheme.Style.TEMPLE:
			_build_island(0.75)
			_build_temple()
		WorldTheme.Style.NEON:
			_build_neon()
		WorldTheme.Style.VOID:
			_build_void()
		_:
			_build_island(0.75)
			_build_flank_crystals()
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

## A floating rock island under the board (World 1 and the island-based worlds).
func _build_island(margin: float) -> void:
	var half := _board_half + Vector2(margin, margin)
	var top_color := _theme.stone_dark.lerp(_theme.foliage, _theme.foliage.a * 0.6)
	# A shallow rim of cut rock (moss in World 1) right under the board…
	var rim_depth := maxf(_board_half.x, _board_half.y) * 0.6 + 1.0
	var island := _mesh(MeshKit.normalize_shades(MeshKit.rock_island(half, rim_depth, 11, _theme.rock, top_color, 36)),
		_rock(), _centre + Vector3(0, -0.62, 0))
	island.name = "Island"
	# …and a scanned boulder hanging beneath it as the island's mass.
	_hang_boulder(half * 0.92, maxf(_board_half.x, _board_half.y) * 1.6 + 2.5, -0.95)


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


func _build_flank_crystals() -> void:
	if _theme.crystal.a <= 0.0:
		return
	var h := _board_half + Vector2(0.75, 0.75)
	var flank: Array[Vector3] = [Vector3(-h.x * 0.7, -1.0, h.y + 0.05), Vector3(h.x + 0.05, -1.3, h.y * 0.4),
		Vector3(h.x * 0.3, -1.7, h.y * 0.85)]
	for i: int in flank.size():
		_crystals(self, _centre + flank[i], 0.9 + _theme.crystal.a * 0.4, 20 + i)


## World 2: a frozen stone chamber. Ice-block walls with icicles, frost pillars at the corners and
## a frozen fall of light; the walls on the camera's side are cut away.
func _build_frost() -> void:
	var margin := 1.3
	var half := _board_half + Vector2(margin, margin)
	var ice := _theme.stone
	var deep := _theme.stone_dark
	# Floor ring of ice flagstones around the board, on a slab.
	var slab := _surface("frost_slab", 0.35)
	_begin()
	MeshKit.append_bevel_box(_tool(slab), _centre + Vector3(0, -0.55, 0), Vector3(half.x * 2.0 + 0.6, 0.6, half.y * 2.0 + 0.6),
		0.1, deep.lightened(0.1), deep.darkened(0.3))
	var x0 := int(floor(_centre.x - half.x))
	var x1 := int(ceil(_centre.x + half.x))
	var z0 := int(floor(_centre.z - half.y))
	var z1 := int(ceil(_centre.z + half.y))
	for z: int in range(z0, z1 + 1):
		for x: int in range(x0, x1 + 1):
			var inside := absf(x - _centre.x) < _board_half.x + 0.2 and absf(z - _centre.z) < _board_half.y + 0.2
			if inside or MeshKit.hash01(x, z, 61) < 0.08:
				continue
			var lift := MeshKit.hash01(x, z, 62) * 0.06
			var tone := ice.darkened(0.1 + MeshKit.hash01(x, z, 63) * 0.2)
			MeshKit.append_bevel_box(_tool(slab), Vector3(x, -0.3 + lift, z), Vector3(0.92, 0.2, 0.92), 0.05, tone,
				deep, Vector2(MeshKit.hash01(x, z, 64), MeshKit.hash01(x, z, 65)) * 6.0)
	_flush(self, "FrostFloor")
	# Rock beneath, as if the chamber were cut out of a floating glacier.
	_mesh(MeshKit.normalize_shades(MeshKit.rock_island(half + Vector2(0.4, 0.4), 1.6, 17, _theme.rock,
		deep.darkened(0.2), 36)), _rock(), _centre + Vector3(0, -0.85, 0))
	_hang_boulder(half * 0.95, maxf(half.x, half.y) * 1.5 + 2.0, -1.2)
	# Four walls of stacked ice blocks, each its own node for the cutaway.
	var wall_height := 2.4
	var thickness := 0.55
	for side: int in 4:
		var along_x := side < 2
		var sign := -1.0 if side % 2 == 0 else 1.0
		var outward := Vector2(0, sign) if along_x else Vector2(sign, 0)
		var length := (half.x if along_x else half.y) * 2.0 + thickness * 2.0
		var base := _centre + Vector3(outward.x * (half.x + thickness * 0.5), -0.25, outward.y * (half.y + thickness * 0.5))
		var node := Node3D.new()
		node.name = "Wall_%d" % side
		add_child(node)
		_begin()
		var courses := 4
		var course_h := wall_height / courses
		for c: int in courses:
			var offset := 0.5 if c % 2 == 1 else 0.0
			var count := int(ceil(length)) + 1
			for k: int in count:
				var t := -length * 0.5 + (k - offset) * 1.0
				var a := maxf(t, -length * 0.5)
				var b := minf(t + 1.0, length * 0.5)
				if b - a < 0.15:
					continue
				var mid := (a + b) * 0.5
				var pos := base + (Vector3(mid, 0, 0) if along_x else Vector3(0, 0, mid)) + Vector3(0, course_h * (c + 0.5), 0)
				var size := Vector3(b - a - 0.04, course_h - 0.04, thickness) if along_x else Vector3(thickness, course_h - 0.04, b - a - 0.04)
				var tone := ice.darkened(0.15 + MeshKit.hash01(side * 31 + k, c, 66) * 0.2)
				MeshKit.append_bevel_box(_tool(slab), pos, size, 0.05, tone.lightened(0.2), tone,
					Vector2(MeshKit.hash01(k, c, 67), MeshKit.hash01(k, side, 68)) * 6.0)
		# Snow cap and icicles along the inner top edge.
		var top := base + Vector3(0, wall_height + 0.06, 0)
		var cap_size := Vector3(length, 0.12, thickness + 0.1) if along_x else Vector3(thickness + 0.1, 0.12, length)
		MeshKit.append_bevel_box(_tool(slab), top, cap_size, 0.05, Color("#E8F4FF"), ice.lightened(0.3))
		var icicle := _crystal_material(Color("#BFE6FF"), 0.5, 0.85)
		var inner_face := -(thickness * 0.5 + 0.02)
		var steps := int(length / 0.35)
		for k: int in steps:
			if MeshKit.hash01(side, k, 69) < 0.35:
				continue
			var t := -length * 0.5 + (k + 0.5) * 0.35
			var drop := 0.25 + MeshKit.hash01(side, k, 70) * 0.7
			var at := top + (Vector3(t, -0.06, outward.y * inner_face) if along_x else Vector3(outward.x * inner_face, -0.06, t))
			MeshKit.append_cone(_tool(icicle), at, at + Vector3(0, -drop, 0), 0.05 + drop * 0.04, Color.WHITE, 5)
		# A frozen fall of light down the middle of the wall.
		var fall := _library.glow("frost_fall", Color("#8FE0FF"), 1.1, 0.35)
		var fall_box := BoxMesh.new()
		fall_box.size = Vector3(0.5, wall_height, 0.02) if along_x else Vector3(0.02, wall_height, 0.5)
		var fall_at := base + Vector3(0, wall_height * 0.5, 0) + Vector3(outward.x, 0, outward.y) * -(thickness * 0.5 + 0.015)
		(_tool(fall)).append_from(fall_box, 0, Transform3D(Basis.IDENTITY, fall_at))
		_flush(node, "WallMesh")
		_tall.append([node, outward])
	# Frost pillars at the corners: stacked drums with a glowing crystal crown.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var node := Node3D.new()
		node.name = "Pillar"
		add_child(node)
		_begin()
		var at := _centre + Vector3(corner.x * (half.x + thickness * 0.5), -0.25, corner.y * (half.y + thickness * 0.5))
		var y := 2.6
		_column(node, at, 0.65, _library.pbr("marble_01", Color(0.62, 0.78, 1.0), 1.0, 0.35, 1.0, 1.0, false))
		_flush(node, "PillarMesh")
		_crystals(node, at + Vector3(0, y, 0), 1.1, 80 + int(corner.x * 3 + corner.y))
		_tall.append([node, corner])


## World 3: an industrial foundry deck. A riveted frame with pipes, flanges and glowing vents,
## pressure tanks at the corners, and support legs down into a lava sea.
func _build_foundry() -> void:
	var metal := _surface("foundry_metal", 0.45, 0.6)
	var hot := _library.glow("foundry_hot", Color("#FF7A1A"), 2.2)
	var beam_color := Color("#3A3C42")
	var pipe_color := Color("#55524E")
	var half := _board_half
	_begin()
	# Frame beams around the deck.
	var beam := 0.5
	for side: int in 4:
		var along_x := side < 2
		var sign := -1.0 if side % 2 == 0 else 1.0
		var length := (half.x if along_x else half.y) * 2.0 + beam * 2.0 + 0.36
		var at := _centre + (Vector3(0, -0.4, sign * (half.y + 0.18 + beam * 0.5)) if along_x
			else Vector3(sign * (half.x + 0.18 + beam * 0.5), -0.4, 0))
		var size := Vector3(length, 0.6, beam) if along_x else Vector3(beam, 0.6, length)
		MeshKit.append_bevel_box(_tool(metal), at, size, 0.06, beam_color.lightened(0.1), beam_color)
		# Pipes along the outer face, with flanges, and hot vents in the beam.
		var out := Vector3(0, 0, sign) if along_x else Vector3(sign, 0, 0)
		var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		for p: int in 2:
			var offset := out * (beam * 0.5 + 0.14 + p * 0.22) + Vector3(0, -0.2 - p * 0.32, 0)
			var radius := 0.11 - p * 0.03
			MeshKit.append_cylinder(_tool(metal), at + offset - dir * length * 0.5, at + offset + dir * length * 0.5,
				radius, pipe_color.darkened(p * 0.2), 8, false)
			var flanges := int(length / 1.6)
			for f: int in flanges:
				var t := -length * 0.5 + (f + 0.5) * length / flanges
				MeshKit.append_cylinder(_tool(metal), at + offset + dir * (t - 0.05), at + offset + dir * (t + 0.05),
					radius + 0.04, pipe_color.lightened(0.15), 8)
		var vents := int(length / 2.2)
		for v: int in vents:
			var t := -length * 0.5 + (v + 0.5) * length / vents
			MeshKit.append_bevel_box(_tool(hot), at + dir * t + out * (beam * 0.5 + 0.005) + Vector3(0, -0.02, 0),
				(Vector3(0.36, 0.12, 0.01) if along_x else Vector3(0.01, 0.12, 0.36)), 0.0, Color.WHITE, Color.WHITE)
	# Support legs into the lava.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := _centre + Vector3(corner.x * (half.x + 0.4), -0.6, corner.y * (half.y + 0.4))
		MeshKit.append_cylinder(_tool(metal), at, at + Vector3(0, -9.0, 0), 0.32, beam_color.darkened(0.2), 8)
	_flush(self, "FoundryFrame")
	# Pressure tanks at the corners (tall: cut away on the camera's side).
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var node := Node3D.new()
		node.name = "Tank"
		add_child(node)
		_begin()
		var at := _centre + Vector3(corner.x * (half.x + 0.95), -0.7, corner.y * (half.y + 0.95))
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
			var at := _centre + Vector3(corner.x * (half.x + 0.4), -0.1, corner.y * (half.y + 0.4)) + along * (0.0 if k == 0 else 0.55)
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
		var at := _centre + Vector3(corner.x * h.x, -0.6, corner.y * h.y)
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
		var at := _centre + Vector3(corner.x * h.x, -0.6, corner.y * h.y)
		_column(node, at, 0.7, _library.pbr("marble_01", Color(0.92, 0.9, 0.86), 1.0, 0.7, 1.0, 1.0, false))
		MeshKit.append_cylinder(_tool(gold), at + Vector3(0, 2.52, 0), at + Vector3(0, 2.56, 0), 0.31, Color.WHITE, 20)
		_flush(node, "ColumnMesh")
		_tall.append([node, corner])
	var spinner := Node3D.new()
	spinner.name = "SealRing"
	spinner.position = _centre + Vector3(0, -2.4, 0)
	add_child(spinner)
	_begin()
	var radius := maxf(_board_half.x, _board_half.y) + 2.2
	MeshKit.append_torus(_tool(gold), Vector3.ZERO, Vector3.UP, radius, 0.06, Color.WHITE, 64, 4)
	MeshKit.append_torus(_tool(gold), Vector3.ZERO, Vector3.UP, radius * 0.86, 0.03, Color.WHITE, 64, 4)
	for k: int in 12:
		var angle := TAU * k / 12.0
		var at := Vector3(cos(angle), 0, sin(angle)) * radius * 0.93
		MeshKit.append_bevel_box(_tool(gold), at, Vector3(0.18, 0.04, 0.18), 0.0, Color.WHITE, Color.WHITE)
	_flush(spinner, "SealRingMesh")
	_spinners.append(spinner)


## World 6: dark tech masonry on stepped plinths, ringed by tall circuit pillars with neon strips.
func _build_neon() -> void:
	var metal := _surface("neon_body", 0.55, 0.3)
	var teal := _library.glow("neon_teal", Color("#3FF2E0"), 2.0)
	var magenta := _library.glow("neon_magenta", Color("#FF3FA0"), 2.0)
	var dark := _theme.stone_dark
	_begin()
	# Stepped plinths under the board.
	for step: int in 3:
		var grow := 0.5 + step * 0.6
		MeshKit.append_bevel_box(_tool(metal), _centre + Vector3(0, -0.85 - step * 0.55, 0),
			Vector3(_board_half.x * 2.0 + grow * 2.0, 0.5, _board_half.y * 2.0 + grow * 2.0) * Vector3(1.0 - step * 0.12, 1, 1.0 - step * 0.12),
			0.06, dark.lightened(0.08), dark.darkened(0.2))
		var trim := _board_half + Vector2(grow, grow) * (1.0 - step * 0.12)
		for side: int in 4:
			var along_x := side < 2
			var sign := -1.0 if side % 2 == 0 else 1.0
			var y := -0.68 - step * 0.55
			var at := _centre + (Vector3(0, y, sign * (_board_half.y + grow) * (1.0 - step * 0.12) + sign * 0.006) if along_x
				else Vector3(sign * (_board_half.x + grow) * (1.0 - step * 0.12) + sign * 0.006, y, 0))
			var size := Vector3(trim.x * 1.6, 0.03, 0.01) if along_x else Vector3(0.01, 0.03, trim.y * 1.6)
			MeshKit.append_bevel_box(_tool(magenta if step % 2 == 0 else teal), at, size, 0.0, Color.WHITE, Color.WHITE)
	_flush(self, "NeonPlinth")
	# Circuit pillars around the board, rising from the depths to varied heights.
	var h := _board_half + Vector2(1.6, 1.6)
	var count := 10
	for i: int in count:
		var angle := TAU * (i + 0.5) / count
		var dir := Vector2(cos(angle), sin(angle))
		# Push onto the rectangle around the board.
		var scale := minf(h.x / maxf(absf(dir.x), 0.001), h.y / maxf(absf(dir.y), 0.001))
		var p := dir * scale
		var top := 0.6 + MeshKit.hash01(i, 1, 71) * 2.6
		var width := 0.55 + MeshKit.hash01(i, 2, 71) * 0.35
		var node := Node3D.new()
		node.name = "NeonPillar"
		add_child(node)
		_begin()
		var base := _centre + Vector3(p.x, 0, p.y)
		MeshKit.append_bevel_box(_tool(metal), base + Vector3(0, (top - 7.0) * 0.5, 0), Vector3(width, top + 7.0, width), 0.05,
			dark.lightened(0.15), dark)
		var strip := teal if i % 3 != 0 else magenta
		var face := Vector3(-dir.x, 0, -dir.y).normalized() * (width * 0.5 + 0.006)
		var strip_size := Vector3(0.06, top + 5.0, 0.01) if absf(dir.y) > absf(dir.x) else Vector3(0.01, top + 5.0, 0.06)
		MeshKit.append_bevel_box(_tool(strip), base + face * Vector3(1, 0, 1) + Vector3(0, (top - 5.0) * 0.5, 0), strip_size,
			0.0, Color.WHITE, Color.WHITE)
		MeshKit.append_bevel_box(_tool(strip), base + Vector3(0, top + 0.03, 0), Vector3(width * 0.6, 0.04, width * 0.6), 0.0,
			Color.WHITE, Color.WHITE)
		_flush(node, "NeonPillarMesh")
		if top > 1.2:
			_tall.append([node, dir])


## World 7: an obsidian monolith in deep space, its sides split by glowing lava veins.
func _build_void() -> void:
	var stone := _surface("void_stone", 0.75)
	var vein := _library.glow("void_vein", Color("#FF8A2A"), 2.0)
	var half := _board_half + Vector2(0.5, 0.5)
	var depth := 3.2
	_begin()
	MeshKit.append_bevel_box(_tool(stone), _centre + Vector3(0, -0.6 - depth * 0.5, 0), Vector3(half.x * 2.0, depth, half.y * 2.0),
		0.12, _theme.stone_dark.lightened(0.05), _theme.rock)
	# Veins: jagged vertical cracks down each face.
	for side: int in 4:
		var along_x := side < 2
		var sign := -1.0 if side % 2 == 0 else 1.0
		var length := (half.x if along_x else half.y) * 2.0
		var cracks := int(length / 1.7)
		for c: int in cracks:
			var t := -length * 0.5 + (c + 0.5) * length / cracks + (MeshKit.hash01(side, c, 81) - 0.5) * 0.8
			var y := -0.7
			var drift := 0.0
			while y > -0.6 - depth + 0.2:
				var seg := 0.25 + MeshKit.hash01(side, c * 13 + int(-y * 10), 82) * 0.35
				var step := (MeshKit.hash01(side, c * 7 + int(-y * 10), 83) - 0.5) * 0.25
				var a := t + drift
				var at := _centre + (Vector3(a, y - seg * 0.5, sign * (half.y + 0.006)) if along_x
					else Vector3(sign * (half.x + 0.006), y - seg * 0.5, a))
				MeshKit.append_bevel_box(_tool(vein), at, (Vector3(0.04, seg, 0.01) if along_x else Vector3(0.01, seg, 0.04)), 0.0,
					Color.WHITE, Color.WHITE)
				drift += step
				y -= seg
	_flush(self, "VoidSlab")
	# Broken teeth along the rim.
	_begin()
	for side: int in 4:
		var along_x := side < 2
		var sign := -1.0 if side % 2 == 0 else 1.0
		var length := (half.x if along_x else half.y) * 2.0
		var teeth := int(length / 0.9)
		for k: int in teeth:
			if MeshKit.hash01(side, k, 84) < 0.4:
				continue
			var t := -length * 0.5 + (k + 0.5) * length / teeth
			var tall := 0.15 + MeshKit.hash01(side, k, 85) * 0.35
			var at := _centre + (Vector3(t, -0.6 + tall * 0.5, sign * (half.y - 0.2)) if along_x
				else Vector3(sign * (half.x - 0.2), -0.6 + tall * 0.5, t))
			MeshKit.append_bevel_box(_tool(stone), at, Vector3(0.5, tall, 0.35) if along_x else Vector3(0.35, tall, 0.5), 0.05,
				_theme.stone, _theme.stone_dark)
	_flush(self, "VoidRim")


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
