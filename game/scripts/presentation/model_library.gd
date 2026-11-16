class_name ModelLibrary
extends RefCounted
## Meshes of the scanned, decimated CC0 models in res://assets/models (see
## assets/third_party/polyhaven/LICENSE.md and tools/blender/process_rocks.py). Loaded once and
## kept for the whole run. Their materials come from MaterialLibrary.pbr (each model's own scan
## textures), so they share the static material cache and its compiled shaders.

const MODELS_DIR := "res://assets/models"

static var _meshes: Dictionary[String, Mesh] = {}


## The first mesh in `<name>.glb`, or null if it is missing.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var scene := load("%s/%s.glb" % [MODELS_DIR, name]) as PackedScene
	var found: Mesh = null
	if scene != null:
		var root := scene.instantiate()
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			found = (node as MeshInstance3D).mesh
			break
		root.free()
	if found == null:
		push_warning("Model %s could not be loaded" % name)
	_meshes[name] = found
	return found


## The scan's own textures, tinted for the world.
static func material(library: MaterialLibrary, name: String, tint: Color) -> StandardMaterial3D:
	return library.pbr(name, tint, 1.0, 1.0, 1.0, 1.0, false)
