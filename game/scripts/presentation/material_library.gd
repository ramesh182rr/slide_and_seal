class_name MaterialLibrary
extends RefCounted
## Cached materials shared by the board, its fixtures and the island diorama.
## Surface detail comes from two procedural noise textures (generated once per run and shared),
## so there are no imported texture files to license or ship.

## Shared by every library: generating noise costs a few milliseconds, so do it once.
static var _detail: NoiseTexture2D
static var _detail_normal: NoiseTexture2D

var _cache: Dictionary[String, StandardMaterial3D] = {}


func get_material(key: String, color: Color, emission: float = 0.0, alpha: float = 1.0,
		metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.metallic = metallic
	material.roughness = roughness
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = material
	return material


## Textured stone/rock/metal for procedural meshes that carry their colour in vertex colours.
func surface(key: String, roughness: float = 0.88, metallic: float = 0.0, uv_scale: float = 1.0,
		normal_strength: float = 0.7) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_texture = detail_texture()
	material.normal_enabled = true
	material.normal_texture = detail_normal()
	material.normal_scale = normal_strength
	material.roughness = roughness
	material.metallic = metallic
	material.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
	_cache[key] = material
	return material


## Unshaded glowing material (energy inlays, trims, beams): bright under the glow pass.
func glow(key: String, color: Color, energy: float = 2.0, alpha: float = 1.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color * energy, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = material
	return material


## Translucent emissive crystal (the core, decorative shards).
func crystal(key: String, color: Color, emission: float = 1.2, alpha: float = 0.88) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.lightened(0.2), alpha)
	material.metallic = 0.3
	material.roughness = 0.12
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	material.rim_enabled = true
	material.rim = 0.6
	material.rim_tint = 0.4
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = material
	return material


## Inverted-hull outline: a slightly larger shell drawn back-faces only, unshaded.
func outline() -> StandardMaterial3D:
	if not _cache.has("outline"):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_FRONT
		material.albedo_color = Palette.CYAN_ENERGY
		_cache["outline"] = material
	return _cache["outline"]


## Grey stone grain (light, 0.7–1.0) that multiplies vertex colours.
static func detail_texture() -> NoiseTexture2D:
	if _detail == null:
		_detail = NoiseTexture2D.new()
		_detail.width = 256
		_detail.height = 256
		_detail.seamless = true
		_detail.generate_mipmaps = true
		_detail.noise = _stone_noise()
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.68, 0.68, 0.7))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		_detail.color_ramp = ramp
	return _detail


static func detail_normal() -> NoiseTexture2D:
	if _detail_normal == null:
		_detail_normal = NoiseTexture2D.new()
		_detail_normal.width = 256
		_detail_normal.height = 256
		_detail_normal.seamless = true
		_detail_normal.as_normal_map = true
		_detail_normal.bump_strength = 6.0
		_detail_normal.generate_mipmaps = true
		_detail_normal.noise = _stone_noise()
	return _detail_normal


static func _stone_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	return noise
