class_name LevelLoader
extends RefCounted
## Loads and validates level JSON (schema v3, see docs/LEVEL_SCHEMA.md).
## Never returns a partially valid level: any error means `level == null`.

const SUPPORTED_SCHEMA_VERSION := 3
const MAX_BOARD_SIDE := 32
const ACCESS_VALUES := ["free", "premium"]
const OBJECT_KINDS := [MovableObject.KIND_BLOCK]
const MECHANISM_NAMES := [
	"gravity_shift", "push_pulse", "portal_network", "switches_seals",
	"rotating_sections", "energy_routing", "magnetic_polarity",
]
## Collections a level may declare. Each must stay empty until its resolver exists.
const MECHANISM_COLLECTIONS := [
	"gravity_zones", "push_devices", "portals", "switches", "gates", "rotating_sections",
	"energy_emitters", "reflectors", "receivers", "magnetic_fields", "magnetic_objects",
]


class LoadResult:
	extends RefCounted
	var level: LevelDefinition = null
	var errors: PackedStringArray = PackedStringArray()

	func is_ok() -> bool:
		return level != null and errors.is_empty()


var _errors: PackedStringArray = PackedStringArray()


static func load_file(path: String) -> LoadResult:
	if not FileAccess.file_exists(path):
		return _failed(PackedStringArray(["%s: file not found" % path]))
	return parse_text(FileAccess.get_file_as_string(path), path)


static func parse_text(text: String, source: String = "<text>") -> LoadResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return _failed(PackedStringArray([
			"%s: invalid JSON at line %d: %s" % [source, json.get_error_line(), json.get_error_message()]]))
	if typeof(json.data) != TYPE_DICTIONARY:
		return _failed(PackedStringArray(["%s: top level must be a JSON object" % source]))
	var result := from_dict(json.data)
	var prefixed := PackedStringArray()
	for message: String in result.errors:
		prefixed.append("%s: %s" % [source, message])
	result.errors = prefixed
	return result


static func from_dict(data: Dictionary) -> LoadResult:
	var loader := LevelLoader.new()
	var level := loader._parse(data)
	if level != null and loader._errors.is_empty():
		loader._validate(level)
	var result := LoadResult.new()
	result.errors = loader._errors
	if result.errors.is_empty():
		result.level = level
	return result


static func _failed(errors: PackedStringArray) -> LoadResult:
	var result := LoadResult.new()
	result.errors = errors
	return result


# --- Structural parsing -------------------------------------------------------

func _parse(data: Dictionary) -> LevelDefinition:
	var version := _int(data.get("schema_version"), "schema_version")
	if not _errors.is_empty():
		return null
	if version != SUPPORTED_SCHEMA_VERSION:
		_error("schema_version %d is not supported (expected %d)" % [version, SUPPORTED_SCHEMA_VERSION])
		return null

	var level := LevelDefinition.new()
	level.schema_version = version
	level.id = _string(data, "id", "")
	level.title = _string(data, "title", "")
	level.world_id = _string(data, "world_id", "")
	level.access = _string(data, "access", "")

	var board := _dict(data, "board", "")
	level.board_size = Vector2i(_int(board.get("width"), "board.width"), _int(board.get("height"), "board.height"))

	var core := _dict(data, "core", "")
	level.core_start = _cell(core.get("position"), "core.position")
	level.start_route_id = _string(core, "route_id", "core")

	var destination := _dict(data, "destination", "")
	level.destination = _cell(destination.get("position"), "destination.position")
	level.seal_id = _string(destination, "seal_id", "destination")

	_parse_walls(level, _dict(data, "terrain", ""))
	_parse_routes(level, _dict(data, "routes", ""))
	_parse_objects(level, _array(data, "objects", "", false))
	if data.has("mechanisms"):
		_parse_mechanisms(_dict(data, "mechanisms", ""))
	_parse_objectives(level, _array(data, "objectives", ""))
	_parse_scoring(level, _dict(data, "scoring", ""))
	return level


func _parse_walls(level: LevelDefinition, terrain: Dictionary) -> void:
	var walls := _array(terrain, "walls", "terrain", false)
	for i: int in walls.size():
		var cell := _cell(walls[i], "terrain.walls[%d]" % i)
		if level.walls.has(cell):
			_error("terrain.walls[%d] duplicates wall %s" % [i, cell])
		level.walls[cell] = true


func _parse_routes(level: LevelDefinition, routes: Dictionary) -> void:
	var route_ids: Array = routes.keys()
	route_ids.sort()
	for route_id: String in route_ids:
		var context := "routes.%s" % route_id
		if typeof(routes[route_id]) != TYPE_DICTIONARY:
			_error("%s must be an object" % context)
			continue
		var data: Dictionary = routes[route_id]
		var route := RouteDefinition.new()
		route.id = route_id
		var nodes := _array(data, "nodes", context)
		for i: int in nodes.size():
			route.nodes.append(_cell(nodes[i], "%s.nodes[%d]" % [context, i]))
		var checkpoints := _array(data, "checkpoints", context, false)
		for i: int in checkpoints.size():
			var checkpoint := _parse_checkpoint(checkpoints[i], "%s.checkpoints[%d]" % [context, i])
			if checkpoint != null:
				route.checkpoints.append(checkpoint)
		level.routes[route.id] = route


func _parse_checkpoint(value: Variant, context: String) -> CheckpointDefinition:
	if typeof(value) != TYPE_DICTIONARY:
		_error("%s must be an object" % context)
		return null
	var data: Dictionary = value
	var checkpoint := CheckpointDefinition.new()
	checkpoint.id = _string(data, "id", context)
	checkpoint.position = _cell(data.get("position"), context + ".position")
	checkpoint.auto_pause = _bool(data, "auto_pause", context, true)
	var allowed := _array(data, "allowed_mechanisms", context, false)
	for i: int in allowed.size():
		var mechanism: Variant = allowed[i]
		if typeof(mechanism) != TYPE_STRING or not MECHANISM_NAMES.has(mechanism):
			_error("%s.allowed_mechanisms[%d] is not a known mechanism" % [context, i])
			continue
		checkpoint.allowed_mechanisms.append(mechanism)
	return checkpoint


func _parse_objects(level: LevelDefinition, objects: Array) -> void:
	for i: int in objects.size():
		var context := "objects[%d]" % i
		if typeof(objects[i]) != TYPE_DICTIONARY:
			_error("%s must be an object" % context)
			continue
		var data: Dictionary = objects[i]
		var kind := _string(data, "kind", context)
		if not kind.is_empty() and not OBJECT_KINDS.has(kind):
			_error("%s.kind '%s' is not supported" % [context, kind])
		var position := _cell(data.get("position"), context + ".position")
		level.initial_objects.append(MovableObject.new(_string(data, "id", context), kind, position))
	level.initial_objects.sort_custom(func(a: MovableObject, b: MovableObject) -> bool: return a.id < b.id)


func _parse_mechanisms(mechanisms: Dictionary) -> void:
	var keys: Array = mechanisms.keys()
	keys.sort()
	for key: String in keys:
		if not MECHANISM_COLLECTIONS.has(key):
			_error("mechanisms.%s is not a known mechanism collection" % key)
			continue
		if typeof(mechanisms[key]) != TYPE_ARRAY:
			_error("mechanisms.%s must be an array" % key)
			continue
		if not (mechanisms[key] as Array).is_empty():
			_error("mechanisms.%s is not supported by the simulation yet" % key)


func _parse_objectives(level: LevelDefinition, objectives: Array) -> void:
	if objectives.is_empty():
		_error("objectives must contain at least one objective")
	for i: int in objectives.size():
		var context := "objectives[%d]" % i
		if typeof(objectives[i]) != TYPE_DICTIONARY:
			_error("%s must be an object" % context)
			continue
		var data: Dictionary = objectives[i]
		var objective_type := _string(data, "type", context)
		if objective_type != "reach_destination":
			_error("%s.type '%s' is not supported" % [context, objective_type])
			continue
		var target := _string(data, "target_id", context)
		if target != level.seal_id:
			_error("%s.target_id '%s' does not match destination.seal_id '%s'" % [context, target, level.seal_id])


func _parse_scoring(level: LevelDefinition, scoring: Dictionary) -> void:
	level.target_actions = _int(scoring.get("target_actions"), "scoring.target_actions")
	var optimal: Variant = scoring.get("optimal_actions")
	level.optimal_actions = -1 if optimal == null else _int(optimal, "scoring.optimal_actions")


# --- Semantic validation ------------------------------------------------------

func _validate(level: LevelDefinition) -> void:
	if not ACCESS_VALUES.has(level.access):
		_error("access '%s' must be one of %s" % [level.access, ACCESS_VALUES])
	var size := level.board_size
	if size.x < 1 or size.y < 1 or size.x > MAX_BOARD_SIDE or size.y > MAX_BOARD_SIDE:
		_error("board size %dx%d must be between 1 and %d per side" % [size.x, size.y, MAX_BOARD_SIDE])
		return
	for cell: Vector2i in level.walls.keys():
		if not level.in_bounds(cell):
			_error("wall %s is out of bounds" % cell)
	if level.target_actions < 0:
		_error("scoring.target_actions must not be negative")
	if level.optimal_actions < -1:
		_error("scoring.optimal_actions must not be negative")

	if not level.routes.has(level.start_route_id):
		_error("core.route_id '%s' does not name a route" % level.start_route_id)
		return
	if level.routes.size() != 1:
		_error("exactly one route segment is supported until junctions are implemented (found %d)" % level.routes.size())
	var checkpoint_ids: Dictionary[String, bool] = {}
	for route_id: String in level.routes.keys():
		_validate_route(level, level.routes[route_id], checkpoint_ids)

	var start_route := level.routes[level.start_route_id]
	if start_route.nodes.size() >= 2:
		if level.core_start != start_route.nodes[0]:
			_error("core.position must equal the first node of route '%s'" % start_route.id)
		if level.destination != start_route.nodes[start_route.last_index()]:
			_error("destination.position must equal the last node of route '%s'" % start_route.id)
	_validate_objects(level)


func _validate_route(level: LevelDefinition, route: RouteDefinition, checkpoint_ids: Dictionary[String, bool]) -> void:
	var context := "routes.%s" % route.id
	if route.nodes.size() < 2:
		_error("%s must have at least 2 nodes" % context)
		return
	var seen: Dictionary[Vector2i, bool] = {}
	for i: int in route.nodes.size():
		var cell := route.nodes[i]
		if not level.in_bounds(cell):
			_error("%s.nodes[%d] %s is out of bounds" % [context, i, cell])
		elif level.is_wall(cell):
			_error("%s.nodes[%d] %s passes through a wall" % [context, i, cell])
		if seen.has(cell):
			_error("%s.nodes[%d] %s revisits a cell" % [context, i, cell])
		seen[cell] = true
		if i > 0 and not Grid.are_orthogonal_neighbours(route.nodes[i - 1], cell):
			_error("%s.nodes[%d] %s is not orthogonally adjacent to the previous node" % [context, i, cell])

	var checkpoint_cells: Dictionary[Vector2i, bool] = {}
	for checkpoint: CheckpointDefinition in route.checkpoints:
		if checkpoint_ids.has(checkpoint.id):
			_error("duplicate checkpoint id '%s'" % checkpoint.id)
		checkpoint_ids[checkpoint.id] = true
		if checkpoint_cells.has(checkpoint.position):
			_error("checkpoint '%s' shares a cell with another checkpoint" % checkpoint.id)
		checkpoint_cells[checkpoint.position] = true
		var index := route.nodes.find(checkpoint.position)
		if index == -1:
			_error("checkpoint '%s' at %s is not on its route" % [checkpoint.id, checkpoint.position])
		elif index == 0 or index == route.last_index():
			_error("checkpoint '%s' must not be on the route's first or last node" % checkpoint.id)


func _validate_objects(level: LevelDefinition) -> void:
	var ids: Dictionary[String, bool] = {}
	var cells: Dictionary[Vector2i, bool] = {}
	for obj: MovableObject in level.initial_objects:
		if ids.has(obj.id):
			_error("duplicate object id '%s'" % obj.id)
		ids[obj.id] = true
		if not level.in_bounds(obj.position):
			_error("object '%s' at %s is out of bounds" % [obj.id, obj.position])
		elif level.is_wall(obj.position):
			_error("object '%s' at %s is inside a wall" % [obj.id, obj.position])
		if cells.has(obj.position):
			_error("object '%s' overlaps another object at %s" % [obj.id, obj.position])
		cells[obj.position] = true
		if obj.position == level.core_start:
			_error("object '%s' must not start on the core's cell" % obj.id)


# --- Typed field helpers ------------------------------------------------------

func _error(message: String) -> void:
	_errors.append(message)


static func _field(context: String, key: String) -> String:
	return key if context.is_empty() else "%s.%s" % [context, key]


func _dict(source: Dictionary, key: String, context: String) -> Dictionary:
	var value: Variant = source.get(key)
	if typeof(value) != TYPE_DICTIONARY:
		_error("%s must be an object" % _field(context, key))
		return {}
	return value


func _array(source: Dictionary, key: String, context: String, required: bool = true) -> Array:
	if not required and not source.has(key):
		return []
	var value: Variant = source.get(key)
	if typeof(value) != TYPE_ARRAY:
		_error("%s must be an array" % _field(context, key))
		return []
	return value


func _string(source: Dictionary, key: String, context: String) -> String:
	var value: Variant = source.get(key)
	if typeof(value) != TYPE_STRING or (value as String).is_empty():
		_error("%s must be a non-empty string" % _field(context, key))
		return ""
	return value


func _bool(source: Dictionary, key: String, context: String, default_value: bool) -> bool:
	if not source.has(key):
		return default_value
	if typeof(source[key]) != TYPE_BOOL:
		_error("%s must be a boolean" % _field(context, key))
		return default_value
	return source[key]


## JSON numbers arrive as floats; accept only integral values.
func _int(value: Variant, label: String) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number == floorf(number) and absf(number) < 1.0e9:
			return int(number)
	_error("%s must be an integer" % label)
	return 0


func _cell(value: Variant, label: String) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		_error("%s must be an [x, y] pair" % label)
		return Vector2i.ZERO
	var pair: Array = value
	return Vector2i(_int(pair[0], label + "[0]"), _int(pair[1], label + "[1]"))
