class_name IslandDecor
extends Node3D
## The floating island the board stands on, plus a few drifting rock fragments and crystals
## (docs/06 §1, docs/07 world themes). Pure scenery: it sits below and around the board, never on a
## cell, so nothing here can be mistaken for something interactive (docs/05 §4). The drift is a
## gentle presentation-only sway; it never touches the puzzle.

const DRIFT_AMPLITUDE := 0.08
const DRIFT_SPEED := 0.6

var _fragments: Array[Node3D] = []
var _rest: Array[float] = []
var _time := 0.0
## Tests and screenshots can freeze the sway.
var animate := true


func build(board_size: Vector2i, theme: WorldTheme, library: MaterialLibrary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_fragments.clear()
	_rest.clear()
	var centre := BoardCoords.board_center(board_size)
	var half := Vector2(board_size.x, board_size.y) * 0.5 * BoardCoords.CELL_SIZE + Vector2(0.75, 0.75)
	var depth := maxf(board_size.x, board_size.y) * 0.75 + 2.0
	var top_color := theme.stone_dark.lerp(theme.foliage, theme.foliage.a * 0.6)
	var rock := library.surface("island_rock", 0.95, 0.0, 0.45, 1.0)
	var island := _add(MeshKit.rock_island(half, depth, 11, theme.rock, top_color, 36), rock,
		centre + Vector3(0, -0.62, 0))
	island.name = "Island"
	# Drifting fragments: at the island's sides and well below the board's surface.
	var spots: Array[Vector3] = [
		Vector3(-half.x - 1.6, -2.2, half.y * 0.2), Vector3(half.x + 1.4, -3.0, -half.y * 0.35),
		Vector3(-half.x * 0.4, -4.4, half.y + 1.4), Vector3(half.x * 0.6, -1.6, half.y + 1.8),
		Vector3(half.x + 1.1, -4.8, half.y * 0.7), Vector3(-half.x - 0.9, -5.4, -half.y * 0.6),
	]
	for i: int in spots.size():
		var size := 0.45 + MeshKit.hash01(i, 3, 5) * 0.55
		var fragment := Node3D.new()
		fragment.name = "Fragment_%d" % i
		fragment.position = centre + spots[i]
		add_child(fragment)
		var mesh := _add(MeshKit.rock_island(Vector2(size, size * 0.85), size * 2.2, 40 + i, theme.rock, top_color, 12),
			rock, Vector3.ZERO, fragment)
		mesh.rotation.y = MeshKit.hash01(i, 9) * TAU
		if theme.crystal.a > 0.0 and i % 2 == 0:
			_add_crystals(fragment, theme, library, Vector3(0, 0.0, 0), 0.5 + size * 0.4, i)
		_fragments.append(fragment)
		_rest.append(fragment.position.y)
	# Crystal clusters on the island's flanks, just under the rim.
	if theme.crystal.a > 0.0:
		var flank: Array[Vector3] = [Vector3(-half.x * 0.7, -1.0, half.y + 0.05), Vector3(half.x + 0.05, -1.3, half.y * 0.4),
			Vector3(half.x * 0.3, -1.7, half.y * 0.85)]
		for i: int in flank.size():
			_add_crystals(self, theme, library, centre + flank[i], 0.9 + theme.crystal.a * 0.4, 20 + i)


func _process(delta: float) -> void:
	if not animate:
		return
	_time += delta
	for i: int in _fragments.size():
		_fragments[i].position.y = _rest[i] + sin(_time * DRIFT_SPEED + i * 1.7) * DRIFT_AMPLITUDE


func fragment_count() -> int:
	return _fragments.size()


func _add_crystals(parent: Node3D, theme: WorldTheme, library: MaterialLibrary, at: Vector3, scale: float,
		seed: int) -> void:
	var material := library.crystal("decor_crystal", theme.crystal, 1.6, 0.9)
	var cluster := _add(MeshKit.crystal_cluster(seed, scale), material, at, parent)
	cluster.rotation.y = MeshKit.hash01(seed, 2) * TAU


func _add(mesh: Mesh, material: Material, at: Vector3, parent: Node = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
