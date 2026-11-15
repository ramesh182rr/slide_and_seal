class_name MaterialLibrary
extends RefCounted
## Cached placeholder materials (D-011), shared by the board and its fixture renderer.

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


## Inverted-hull outline: a slightly larger shell drawn back-faces only, unshaded.
func outline() -> StandardMaterial3D:
	if not _cache.has("outline"):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_FRONT
		material.albedo_color = Palette.CYAN_ENERGY
		_cache["outline"] = material
	return _cache["outline"]
