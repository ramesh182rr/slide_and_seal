class_name MeshKit
extends RefCounted
## Procedural geometry for the board and its diorama: beveled blocks, floating rock islands and
## crystals. Everything is generated from code (no imported models) and is deterministic: the
## "random" variation comes from a hash of integer coordinates, never from a random generator.
## Godot treats clockwise triangles as front faces, so every face is emitted with
## (b - a) × (c - a) pointing away from its outward normal.


## Deterministic pseudo-random value in [0, 1) for integer coordinates.
static func hash01(x: int, y: int, salt: int = 0) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 982451653) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0


## One flat-shaded quad (corners in order around the face) facing `outward`.
static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
		color: Color, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2) -> void:
	var corners := [a, b, c, d]
	var uvs := [uv_a, uv_b, uv_c, uv_d]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		corners.reverse()
		uvs.reverse()
	var normal := outward.normalized()
	for i: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.set_uv(uvs[i])
		tool.add_vertex(corners[i])


static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, outward_hint: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	var points := [a, b, c]
	if normal.dot(outward_hint) > 0.0:
		points = [a, c, b]
	else:
		normal = -normal
	normal = normal.normalized()
	for p: Vector3 in points:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.set_uv(Vector2(p.x + p.y * 0.5, p.z + p.y * 0.5))
		tool.add_vertex(p)


## A box whose top edges are chamfered by `bevel` (the bottom is left open: it is never seen).
## The top face takes `top_color`, chamfers and sides `side_color`. UVs are planar in world units
## plus `uv_offset`, so a tiling stone texture never repeats identically on neighbouring blocks.
static func append_bevel_box(tool: SurfaceTool, center: Vector3, size: Vector3, bevel: float,
		top_color: Color, side_color: Color, uv_offset: Vector2 = Vector2.ZERO) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	var top := center.y + h.y
	var ring := top - b
	var bottom := center.y - h.y
	var x0 := center.x - h.x
	var x1 := center.x + h.x
	var z0 := center.z - h.z
	var z1 := center.z + h.z
	var o := uv_offset
	# Top face, inset by the bevel.
	quad(tool, Vector3(x0 + b, top, z0 + b), Vector3(x1 - b, top, z0 + b), Vector3(x1 - b, top, z1 - b),
		Vector3(x0 + b, top, z1 - b), Vector3.UP, top_color,
		o + Vector2(x0 + b, z0 + b), o + Vector2(x1 - b, z0 + b), o + Vector2(x1 - b, z1 - b), o + Vector2(x0 + b, z1 - b))
	# Chamfers: lighter than the sides so the edges catch the key light.
	var chamfer := side_color.lerp(top_color, 0.7).lightened(0.08)
	quad(tool, Vector3(x0 + b, top, z0 + b), Vector3(x1 - b, top, z0 + b), Vector3(x1, ring, z0), Vector3(x0, ring, z0),
		Vector3(0, 1, -1), chamfer, o + Vector2(x0, 0), o + Vector2(x1, 0), o + Vector2(x1, b), o + Vector2(x0, b))
	quad(tool, Vector3(x1 - b, top, z1 - b), Vector3(x0 + b, top, z1 - b), Vector3(x0, ring, z1), Vector3(x1, ring, z1),
		Vector3(0, 1, 1), chamfer, o + Vector2(x1, 0), o + Vector2(x0, 0), o + Vector2(x0, b), o + Vector2(x1, b))
	quad(tool, Vector3(x0 + b, top, z1 - b), Vector3(x0 + b, top, z0 + b), Vector3(x0, ring, z0), Vector3(x0, ring, z1),
		Vector3(-1, 1, 0), chamfer, o + Vector2(z1, 0), o + Vector2(z0, 0), o + Vector2(z0, b), o + Vector2(z1, b))
	quad(tool, Vector3(x1 - b, top, z0 + b), Vector3(x1 - b, top, z1 - b), Vector3(x1, ring, z1), Vector3(x1, ring, z0),
		Vector3(1, 1, 0), chamfer, o + Vector2(z0, 0), o + Vector2(z1, 0), o + Vector2(z1, b), o + Vector2(z0, b))
	# Sides.
	var v0 := o.y + top
	quad(tool, Vector3(x0, ring, z0), Vector3(x1, ring, z0), Vector3(x1, bottom, z0), Vector3(x0, bottom, z0),
		Vector3.FORWARD, side_color, Vector2(o.x + x0, v0 - ring), Vector2(o.x + x1, v0 - ring),
		Vector2(o.x + x1, v0 - bottom), Vector2(o.x + x0, v0 - bottom))
	quad(tool, Vector3(x1, ring, z1), Vector3(x0, ring, z1), Vector3(x0, bottom, z1), Vector3(x1, bottom, z1),
		Vector3.BACK, side_color, Vector2(o.x + x1, v0 - ring), Vector2(o.x + x0, v0 - ring),
		Vector2(o.x + x0, v0 - bottom), Vector2(o.x + x1, v0 - bottom))
	quad(tool, Vector3(x0, ring, z1), Vector3(x0, ring, z0), Vector3(x0, bottom, z0), Vector3(x0, bottom, z1),
		Vector3.LEFT, side_color, Vector2(o.x + z1, v0 - ring), Vector2(o.x + z0, v0 - ring),
		Vector2(o.x + z0, v0 - bottom), Vector2(o.x + z1, v0 - bottom))
	quad(tool, Vector3(x1, ring, z0), Vector3(x1, ring, z1), Vector3(x1, bottom, z1), Vector3(x1, bottom, z0),
		Vector3.RIGHT, side_color, Vector2(o.x + z0, v0 - ring), Vector2(o.x + z1, v0 - ring),
		Vector2(o.x + z1, v0 - bottom), Vector2(o.x + z0, v0 - bottom))


static func bevel_box(size: Vector3, bevel: float, top_color: Color = Color.WHITE,
		side_color: Color = Color.WHITE) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_bevel_box(tool, Vector3.ZERO, size, bevel, top_color, side_color)
	return tool.commit()


## A floating rock island: a rounded-rectangle top of half extents `half` (x, z) at y = 0 that
## tapers, jaggedly, to a point `depth` below. `top_color` tints the upper rim (moss/stone).
static func rock_island(half: Vector2, depth: float, seed: int, rock_color: Color, top_color: Color,
		segments: int = 28) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Ring scale (relative to the top) and height (fraction of depth), top to bottom.
	var scales := [1.0, 0.97, 0.82, 0.62, 0.38, 0.16]
	var heights := [0.0, 0.08, 0.28, 0.52, 0.76, 0.93]
	var rings: Array[PackedVector3Array] = []
	for r: int in scales.size():
		var ring := PackedVector3Array()
		for s: int in segments:
			var angle := TAU * s / segments
			var dir := Vector2(cos(angle), sin(angle))
			# A superellipse hugs the rectangular board better than a circle.
			var px := signf(dir.x) * pow(absf(dir.x), 0.45)
			var pz := signf(dir.y) * pow(absf(dir.y), 0.45)
			var jitter := 1.0 if r == 0 else 0.82 + 0.36 * hash01(s, r, seed)
			var drop := 0.0 if r == 0 else (hash01(s, r, seed + 7) - 0.5) * depth * 0.12
			ring.append(Vector3(px * half.x * scales[r] * jitter, -heights[r] * depth + drop,
				pz * half.y * scales[r] * jitter))
		rings.append(ring)
	var tip := Vector3((hash01(1, 2, seed) - 0.5) * half.x * 0.3, -depth, (hash01(3, 4, seed) - 0.5) * half.y * 0.3)
	# Top cap (a fan; it is mostly hidden under the board).
	var centre := Vector3.ZERO
	for s: int in segments:
		triangle(tool, centre, rings[0][s], rings[0][(s + 1) % segments], top_color, Vector3.UP)
	for r: int in range(1, rings.size()):
		var shade := rock_color.darkened(0.12 * r)
		var band := shade.lightened(0.1) if r % 2 == 1 else shade
		var color := top_color if r == 1 else band
		for s: int in segments:
			var a := rings[r - 1][s]
			var b := rings[r - 1][(s + 1) % segments]
			var c := rings[r][(s + 1) % segments]
			var d := rings[r][s]
			var outward := ((a + b + c + d) * 0.25) * Vector3(1, 0, 1)
			triangle(tool, a, b, c, color, outward)
			triangle(tool, a, c, d, color, outward)
	var last := rings.back() as PackedVector3Array
	for s: int in segments:
		var a := last[s]
		var b := last[(s + 1) % segments]
		triangle(tool, a, b, tip, rock_color.darkened(0.7), (a + b) * 0.5 * Vector3(1, 0, 1) + Vector3.DOWN)
	return tool.commit()


## A cluster of hexagonal crystal shards around the origin.
static func crystal_cluster(seed: int, scale: float = 1.0) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 3 + int(hash01(seed, 1) * 3.0)
	for i: int in count:
		var height := (0.35 + hash01(seed, i, 3) * 0.55) * scale
		var radius := (0.06 + hash01(seed, i, 5) * 0.05) * scale
		var lean := Vector3((hash01(seed, i, 7) - 0.5) * 0.7, 1.0, (hash01(seed, i, 9) - 0.5) * 0.7).normalized()
		var base := Vector3((hash01(seed, i, 11) - 0.5) * 0.3, 0, (hash01(seed, i, 13) - 0.5) * 0.3) * scale
		_append_shard(tool, base, lean, height, radius)
	return tool.commit()


static func _append_shard(tool: SurfaceTool, base: Vector3, axis: Vector3, height: float, radius: float) -> void:
	var side := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
	var other := axis.cross(side)
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for k: int in 6:
		var angle := TAU * k / 6.0
		var offset := (side * cos(angle) + other * sin(angle)) * radius
		bottom.append(base + offset)
		top.append(base + offset + axis * height * 0.75)
	var apex := base + axis * height
	var core := base + axis * height * 0.4
	for k: int in 6:
		var n := (k + 1) % 6
		var mid := (bottom[k] + top[n]) * 0.5
		triangle(tool, bottom[k], top[k], top[n], Color.WHITE, mid - core)
		triangle(tool, bottom[k], top[n], bottom[n], Color.WHITE, mid - core)
		triangle(tool, top[k], apex, top[n], Color.WHITE, (top[k] + top[n] + apex) / 3.0 - core)


## Flat-shaded octahedron: `radius` at the equator, `half_height` to each tip.
static func octahedron(radius: float, half_height: float) -> ArrayMesh:
	var top := Vector3(0, half_height, 0)
	var bottom := Vector3(0, -half_height, 0)
	var ring: Array[Vector3] = [Vector3(radius, 0, 0), Vector3(0, 0, -radius), Vector3(-radius, 0, 0), Vector3(0, 0, radius)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		for vertex: Vector3 in [top, b, a, bottom, a, b]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()


## A cylinder from `a` to `b` (any orientation) with flat caps. Faceted on purpose: it reads as
## machined metal or cut stone and keeps vertex counts low.
static func append_cylinder(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color,
		segments: int = 10, caps: bool = true) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	for i: int in segments:
		var angle := TAU * i / segments
		var offset := (u * cos(angle) + v * sin(angle)) * radius
		ring_a.append(a + offset)
		ring_b.append(b + offset)
	var cap_color := color.lightened(0.1)
	for i: int in segments:
		var n := (i + 1) % segments
		var mid := (ring_a[i] + ring_a[n]) * 0.5 - a
		quad(tool, ring_a[i], ring_a[n], ring_b[n], ring_b[i], mid, color,
			Vector2(float(i) / segments, 0), Vector2(float(n) / segments, 0), Vector2(float(n) / segments, 1),
			Vector2(float(i) / segments, 1))
		if caps:
			triangle(tool, b, ring_b[i], ring_b[n], cap_color, axis)
			triangle(tool, a, ring_a[n], ring_a[i], color.darkened(0.2), -axis)


## A cone with its base circle at `base` and its point at `tip` (icicles, spikes, stalactites).
static func append_cone(tool: SurfaceTool, base: Vector3, tip: Vector3, radius: float, color: Color,
		segments: int = 6) -> void:
	var axis := (tip - base).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	for i: int in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := base + (u * cos(a0) + v * sin(a0)) * radius
		var p1 := base + (u * cos(a1) + v * sin(a1)) * radius
		triangle(tool, p0, p1, tip, color, (p0 + p1) * 0.5 - base)
		triangle(tool, base, p1, p0, color.darkened(0.2), -axis)


## A torus in the plane through `centre` perpendicular to `normal`.
static func append_torus(tool: SurfaceTool, centre: Vector3, normal: Vector3, radius: float, thickness: float,
		color: Color, segments: int = 24, sides: int = 6) -> void:
	var axis := normal.normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var rings: Array[PackedVector3Array] = []
	for i: int in segments:
		var angle := TAU * i / segments
		var radial := u * cos(angle) + v * sin(angle)
		var ring := PackedVector3Array()
		for k: int in sides:
			var phi := TAU * k / sides
			ring.append(centre + radial * (radius + cos(phi) * thickness) + axis * sin(phi) * thickness)
		rings.append(ring)
	for i: int in segments:
		var n := (i + 1) % segments
		var radial := (u * cos(TAU * (i + 0.5) / segments) + v * sin(TAU * (i + 0.5) / segments))
		for k: int in sides:
			var m := (k + 1) % sides
			var face := (rings[i][k] + rings[i][m] + rings[n][m] + rings[n][k]) * 0.25
			var tube_centre := centre + radial * radius
			quad(tool, rings[i][k], rings[i][m], rings[n][m], rings[n][k], face - tube_centre, color,
				Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))


## True for scanned (PBR) materials that use vertex colours as a shade multiplier.
static func is_shaded_pbr(material: Material) -> bool:
	var standard := material as StandardMaterial3D
	return standard != null and standard.vertex_color_use_as_albedo and standard.normal_texture != null \
		and standard.albedo_texture != null and not (standard.albedo_texture is NoiseTexture2D)


## Turns absolute vertex colours into grey shade factors relative to the brightest vertex, so a
## scanned texture keeps its own colour while edges, sides and per-tile variation stay darker.
static func normalize_shades(mesh: ArrayMesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if not colors.is_empty():
			var brightest := 0.001
			for c: Color in colors:
				brightest = maxf(brightest, c.get_luminance())
			for i: int in colors.size():
				var v := clampf(colors[i].get_luminance() / brightest, 0.25, 1.0)
				colors[i] = Color(v, v, v)
			arrays[Mesh.ARRAY_COLOR] = colors
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
