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
