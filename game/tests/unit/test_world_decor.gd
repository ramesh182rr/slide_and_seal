extends TestCase
## M13 world environments: every style builds, and tall scenery on the camera's side is cut away.


func _decor(world_id: String) -> IslandDecor:
	var decor := IslandDecor.new()
	decor.animate = false
	decor.build(Vector2i(8, 8), WorldTheme.for_world(world_id), MaterialLibrary.new())
	return decor


func test_every_world_style_builds_scenery() -> void:
	for id: String in WorldTheme.ALL_WORLDS:
		var decor := _decor(id)
		assert_true(decor.get_child_count() > 0, "%s builds scenery" % id)
		assert_true(decor.fragment_count() > 0, "%s has drifting fragments" % id)
		decor.free()


func test_frost_chamber_cuts_away_walls_facing_the_camera() -> void:
	var decor := _decor("world_02_gravity_works")
	decor.set_view_yaw(45.0)  # Default view: camera towards +x, +z.
	assert_false((decor.get_node("Wall_1") as Node3D).visible, "+z wall is between camera and board")
	assert_false((decor.get_node("Wall_3") as Node3D).visible, "+x wall is between camera and board")
	assert_true((decor.get_node("Wall_0") as Node3D).visible, "-z wall stays as a backdrop")
	assert_true((decor.get_node("Wall_2") as Node3D).visible, "-x wall stays as a backdrop")
	decor.set_view_yaw(225.0)  # Turned half way round: the other two walls.
	assert_true((decor.get_node("Wall_1") as Node3D).visible)
	assert_false((decor.get_node("Wall_0") as Node3D).visible)
	decor.free()


func test_same_material_request_is_shared_across_libraries() -> void:
	# Shaders stay compiled only while a material uses them (Compatibility renderer), so boards
	# built by different libraries must share materials.
	var a := MaterialLibrary.new().glow("route", Palette.CYAN_ENERGY, 2.6)
	var b := MaterialLibrary.new().glow("route", Palette.CYAN_ENERGY, 2.6)
	assert_true(a == b, "one material for equal requests")
	var c := MaterialLibrary.new().glow("route", Palette.MINT_SUCCESS, 2.6)
	assert_false(a == c, "different colours never collide")


## M15: every world has its own blocks and gates, all the same playable size.
func test_every_world_builds_its_own_pieces_at_cell_size() -> void:
	var library := MaterialLibrary.new()
	var block_materials: Dictionary[Material, bool] = {}
	for id: String in WorldTheme.ALL_WORLDS:
		var kit := PieceKit.new(library, WorldTheme.for_world(id))
		for pushable: bool in [true, false]:
			var block := kit.block(pushable)
			var size := block.mesh.get_aabb().size
			assert_true(absf(size.x - BoardRenderer3D.BLOCK_SIZE) < 0.01 and absf(size.z - BoardRenderer3D.BLOCK_SIZE) < 0.01,
				"%s block body matches the picker's box" % id)
			if pushable:
				block_materials[block.material_override] = true
			assert_eq(block.get_child_count() > 0, true, "%s block has detail" % id)
			block.free()
		for inverted: bool in [false, true]:
			var gate := kit.gate(Palette.GATE_INVERTED if inverted else Palette.MECHANISM_AMBER, inverted)
			var box := gate.mesh.get_aabb()
			assert_true(box.size.x <= 0.9 and box.size.z <= 0.9, "%s gate stays inside its cell" % id)
			assert_true(absf(box.end.y - MechanismFixtures3D.GATE_HEIGHT * 0.5) < 0.02,
				"%s gate rises to the standard height" % id)
			gate.free()
		assert_eq(kit.core_meshes().size(), 2)
	assert_eq(block_materials.size(), WorldTheme.ALL_WORLDS.size(), "each world's pushable block has its own material")
