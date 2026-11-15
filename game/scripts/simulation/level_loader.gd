class_name LevelLoader
extends RefCounted
## Loads and validates level JSON (schema v3, see docs/LEVEL_SCHEMA.md).
## Never returns a partially valid level: any error means `level == null`.

const SUPPORTED_SCHEMA_VERSION := 3
const MAX_BOARD_SIDE := 32
const ACCESS_VALUES := ["free", "premium"]
const OBJECT_KINDS := [MovableObject.KIND_BLOCK]
## Collections a level may declare. Only gravity_zones, switches and gates are implemented; the rest must stay empty.
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
	if data.has("setup"):
		var setup := _dict(data, "setup", "")
		level.setup_allowed_mechanisms = _parse_allowed_mechanisms(
			_array(setup, "allowed_mechanisms", "setup", false), "setup")
	if data.has("mechanisms"):
		_parse_mechanisms(level, _dict(data, "mechanisms", ""))
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
	checkpoint.allowed_mechanisms = _parse_allowed_mechanisms(
		_array(data, "allowed_mechanisms", context, false), context)
	return checkpoint


func _parse_allowed_mechanisms(values: Array, context: String) -> PackedStringArray:
	var allowed := PackedStringArray()
	for i: int in values.size():
		var label := "%s.allowed_mechanisms[%d]" % [context, i]
		var mechanism: Variant = values[i]
		if typeof(mechanism) != TYPE_STRING or not MechanismIds.ALL.has(mechanism):
			_error("%s is not a known mechanism" % label)
		elif not MechanismIds.IMPLEMENTED.has(mechanism):
			_error("%s '%s' is not supported by the simulation yet" % [label, mechanism])
		elif allowed.has(mechanism):
			_error("%s '%s' is listed twice" % [label, mechanism])
		else:
			allowed.append(mechanism)
	return allowed


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
		var obj := MovableObject.new(_string(data, "id", context), kind, position)
		obj.pushable = _bool(data, "pushable", context, true)
		obj.gravity_affected = _bool(data, "gravity_affected", context, true)
		level.initial_objects.append(obj)
	level.initial_objects.sort_custom(func(a: MovableObject, b: MovableObject) -> bool: return a.id < b.id)


func _parse_mechanisms(level: LevelDefinition, mechanisms: Dictionary) -> void:
	var keys: Array = mechanisms.keys()
	keys.sort()
	for key: String in keys:
		if not MECHANISM_COLLECTIONS.has(key):
			_error("mechanisms.%s is not a known mechanism collection" % key)
			continue
		if typeof(mechanisms[key]) != TYPE_ARRAY:
			_error("mechanisms.%s must be an array" % key)
			continue
		var entries: Array = mechanisms[key]
		for i: int in entries.size():
			var context := "mechanisms.%s[%d]" % [key, i]
			match key:
				"gravity_zones":
					var zone := _parse_gravity_zone(entries[i], context)
					if zone != null:
						level.gravity_zones.append(zone)
				"switches":
					var switch_def := _parse_switch(entries[i], context)
					if switch_def != null:
						level.switches.append(switch_def)
				"gates":
					var gate := _parse_gate(entries[i], context)
					if gate != null:
						level.gates.append(gate)
				"portals":
					var portal := _parse_portal(entries[i], context)
					if portal != null:
						level.portals.append(portal)
				"rotating_sections":
					var section := _parse_rotating_section(entries[i], context)
					if section != null:
						level.rotating_sections.append(section)
				_:
					_error("mechanisms.%s is not supported by the simulation yet" % key)
					break
	level.gravity_zones.sort_custom(
		func(a: GravityZoneDefinition, b: GravityZoneDefinition) -> bool: return a.id < b.id)
	level.switches.sort_custom(func(a: SwitchDefinition, b: SwitchDefinition) -> bool: return a.id < b.id)
	level.gates.sort_custom(func(a: GateDefinition, b: GateDefinition) -> bool: return a.id < b.id)
	level.portals.sort_custom(func(a: PortalDefinition, b: PortalDefinition) -> bool: return a.id < b.id)
	level.rotating_sections.sort_custom(
		func(a: RotatingSectionDefinition, b: RotatingSectionDefinition) -> bool: return a.id < b.id)


func _parse_rotating_section(value: Variant, context: String) -> RotatingSectionDefinition:
	if typeof(value) != TYPE_DICTIONARY:
		_error("%s must be an object" % context)
		return null
	var data: Dictionary = value
	var section := RotatingSectionDefinition.new()
	section.id = _string(data, "id", context)
	section.origin = _cell(data.get("position"), context + ".position")
	section.size = _int(data.get("size"), context + ".size")
	section.allow_clockwise = false
	section.allow_counterclockwise = false
	var allowed := _array(data, "allowed_directions", context)
	for i: int in allowed.size():
		match allowed[i]:
			"clockwise":
				section.allow_clockwise = true
			"counterclockwise":
				section.allow_counterclockwise = true
			_:
				_error("%s.allowed_directions[%d] must be clockwise or counterclockwise" % [context, i])
	if allowed.is_empty():
		_error("%s.allowed_directions must not be empty" % context)
	return section


func _parse_portal(value: Variant, context: String) -> PortalDefinition:
	if typeof(value) != TYPE_DICTIONARY:
		_error("%s must be an object" % context)
		return null
	var data: Dictionary = value
	var portal := PortalDefinition.new()
	portal.id = _string(data, "id", context)
	portal.position = _cell(data.get("position"), context + ".position")
	if data.has("exit"):
		portal.exit_id = _string(data, "exit", context)
	var requires := _array(data, "requires", context, false)
	for i: int in requires.size():
		if typeof(requires[i]) != TYPE_STRING:
			_error("%s.requires[%d] must be a switch id" % [context, i])
		else:
			portal.requires.append(requires[i])
	return portal


func _parse_switch(value: Variant, context: String) -> SwitchDefinition:
	if typeof(value) != TYPE_DICTIONARY:
		_error("%s must be an object" % context)
		return null
	var data: Dictionary = value
	var switch_def := SwitchDefinition.new()
	switch_def.id = _string(data, "id", context)
	switch_def.position = _cell(data.get("position"), context + ".position")
	match _string(data, "kind", context):
		"pressure":
			switch_def.kind = SwitchDefinition.Kind.PRESSURE
			if data.has("initially_on"):
				_error("%s.initially_on only applies to toggle switches" % context)
		"toggle":
			switch_def.kind = SwitchDefinition.Kind.TOGGLE
			switch_def.initially_on = _bool(data, "initially_on", context, false)
		var other:
			if other != "":
				_error("%s.kind '%s' must be pressure or toggle" % [context, other])
	return switch_def


func _parse_gate(value: Variant, context: String) -> GateDefinition:
	if typeof(value) != TYPE_DICTIONARY:
		_error("%s must be an object" % context)
		return null
	var data: Dictionary = value
	var gate := GateDefinition.new()
	gate.id = _string(data, "id", context)
	gate.position = _cell(data.get("position"), context + ".position")
	var requires := _array(data, "requires", context)
	for i: int in requires.size():
		if typeof(requires[i]) != TYPE_STRING:
			_error("%s.requires[%d] must be a switch id" % [context, i])
		else:
			gate.requires.append(requires[i])
	return gate


func _parse_gravity_zone(value: Variant, context: String) -> GravityZoneDefinition:
	if typeof(value) != TYPE_DICTIONARY:
		_error("%s must be an object" % context)
		return null
	var data: Dictionary = value
	var zone := GravityZoneDefinition.new()
	zone.id = _string(data, "id", context)
	zone.rect = Rect2i(_cell(data.get("position"), context + ".position"), _cell(data.get("size"), context + ".size"))
	zone.initial_direction = _direction(data.get("direction"), context + ".direction") as Grid.Direction
	var allowed := _array(data, "allowed_directions", context)
	for i: int in allowed.size():
		var direction := _direction(allowed[i], "%s.allowed_directions[%d]" % [context, i]) as Grid.Direction
		if zone.allowed_directions.has(direction):
			_error("%s.allowed_directions[%d] is listed twice" % [context, i])
		zone.allowed_directions.append(direction)
	return zone


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
	var checkpoint_ids: Dictionary[String, bool] = {}
	var route_cells: Dictionary[Vector2i, bool] = {}
	for route_id: String in level.routes.keys():
		_validate_route(level, level.routes[route_id], checkpoint_ids, route_cells)

	var start_route := level.routes[level.start_route_id]
	if start_route.nodes.size() >= 2 and level.core_start != start_route.nodes[0]:
		_error("core.position must equal the first node of route '%s'" % start_route.id)
	_validate_objects(level)
	_validate_gravity_zones(level)
	_validate_switches_and_gates(level)
	_validate_portals(level)
	_validate_rotating_sections(level)
	if _errors.is_empty():
		_classify_track_pieces(level)
	if _errors.is_empty():
		_validate_route_graph(level)
	_validate_mechanism_availability(level)
	if _errors.is_empty():
		_validate_initial_state_settled(level)


## `seen` is shared across segments: no cell may appear twice on any route.
func _validate_route(level: LevelDefinition, route: RouteDefinition, checkpoint_ids: Dictionary[String, bool],
		seen: Dictionary[Vector2i, bool]) -> void:
	var context := "routes.%s" % route.id
	if route.nodes.size() < 2:
		_error("%s must have at least 2 nodes" % context)
		return
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


func _validate_gravity_zones(level: LevelDefinition) -> void:
	var ids: Dictionary[String, bool] = {}
	var board := Rect2i(Vector2i.ZERO, level.board_size)
	for i: int in level.gravity_zones.size():
		var zone := level.gravity_zones[i]
		if ids.has(zone.id):
			_error("duplicate gravity zone id '%s'" % zone.id)
		ids[zone.id] = true
		if zone.rect.size.x < 1 or zone.rect.size.y < 1:
			_error("gravity zone '%s' must have a positive size" % zone.id)
		elif not board.encloses(zone.rect):
			_error("gravity zone '%s' extends outside the board" % zone.id)
		if zone.allowed_directions.is_empty():
			_error("gravity zone '%s' must allow at least one direction" % zone.id)
		elif not zone.allowed_directions.has(zone.initial_direction):
			_error("gravity zone '%s' initial direction must be one of its allowed directions" % zone.id)
		for j: int in range(i + 1, level.gravity_zones.size()):
			if zone.rect.intersects(level.gravity_zones[j].rect):
				_error("gravity zones '%s' and '%s' overlap" % [zone.id, level.gravity_zones[j].id])


func _validate_switches_and_gates(level: LevelDefinition) -> void:
	var ids: Dictionary[String, bool] = {}
	var switch_cells: Dictionary[Vector2i, bool] = {}
	for switch_def: SwitchDefinition in level.switches:
		if ids.has(switch_def.id):
			_error("duplicate switch or gate id '%s'" % switch_def.id)
		ids[switch_def.id] = true
		_validate_fixture_cell(level, "switch '%s'" % switch_def.id, switch_def.position)
		if switch_cells.has(switch_def.position):
			_error("switch '%s' shares a cell with another switch" % switch_def.id)
		switch_cells[switch_def.position] = true
	var gate_cells: Dictionary[Vector2i, bool] = {}
	for gate: GateDefinition in level.gates:
		if ids.has(gate.id):
			_error("duplicate switch or gate id '%s'" % gate.id)
		ids[gate.id] = true
		_validate_fixture_cell(level, "gate '%s'" % gate.id, gate.position)
		if gate_cells.has(gate.position):
			_error("gate '%s' shares a cell with another gate" % gate.id)
		gate_cells[gate.position] = true
		if switch_cells.has(gate.position):
			_error("gate '%s' shares a cell with a switch" % gate.id)
		if gate.requires.is_empty():
			_error("gate '%s' must require at least one switch" % gate.id)
		var seen: Dictionary[String, bool] = {}
		for switch_id: String in gate.requires:
			if level.switch_by_id(switch_id) == null:
				_error("gate '%s' requires unknown switch '%s'" % [gate.id, switch_id])
			if seen.has(switch_id):
				_error("gate '%s' lists switch '%s' twice" % [gate.id, switch_id])
			seen[switch_id] = true


func _validate_portals(level: LevelDefinition) -> void:
	var ids: Dictionary[String, bool] = {}
	var cells: Dictionary[Vector2i, bool] = {}
	for portal: PortalDefinition in level.portals:
		if ids.has(portal.id):
			_error("duplicate portal id '%s'" % portal.id)
		ids[portal.id] = true
		_validate_fixture_cell(level, "portal '%s'" % portal.id, portal.position)
		if cells.has(portal.position):
			_error("portal '%s' shares a cell with another portal" % portal.id)
		cells[portal.position] = true
		if level.gate_at(portal.position) != null:
			_error("portal '%s' shares a cell with a gate" % portal.id)
		for switch_def: SwitchDefinition in level.switches:
			if switch_def.position == portal.position:
				_error("portal '%s' shares a cell with a switch" % portal.id)
		if portal.exit_id != "":
			if portal.exit_id == portal.id:
				_error("portal '%s' cannot exit to itself" % portal.id)
			elif level.portal_by_id(portal.exit_id) == null:
				_error("portal '%s' exits to unknown portal '%s'" % [portal.id, portal.exit_id])
		for switch_id: String in portal.requires:
			if level.switch_by_id(switch_id) == null:
				_error("portal '%s' requires unknown switch '%s'" % [portal.id, switch_id])
		# On a route, a portal must be a segment's entry (last node) or exit (first node).
		for route: RouteDefinition in level.routes.values():
			var index := route.nodes.find(portal.position)
			if index > 0 and index < route.last_index():
				_error("portal '%s' lies inside route '%s'; portals must end or start a segment" % [portal.id, route.id])


func _validate_rotating_sections(level: LevelDefinition) -> void:
	var board := Rect2i(Vector2i.ZERO, level.board_size)
	var ids: Dictionary[String, bool] = {}
	for i: int in level.rotating_sections.size():
		var section := level.rotating_sections[i]
		if ids.has(section.id):
			_error("duplicate rotating section id '%s'" % section.id)
		ids[section.id] = true
		if section.size < 2:
			_error("rotating section '%s' must be at least 2x2" % section.id)
			continue
		if not board.encloses(section.rect()):
			_error("rotating section '%s' extends outside the board" % section.id)
		for j: int in range(i + 1, level.rotating_sections.size()):
			if section.rect().intersects(level.rotating_sections[j].rect()):
				_error("rotating sections '%s' and '%s' overlap" % [section.id, level.rotating_sections[j].id])
		for zone: GravityZoneDefinition in level.gravity_zones:
			if section.rect().intersects(zone.rect):
				_error("rotating section '%s' overlaps gravity zone '%s'" % [section.id, zone.id])
		# First version (D-018): only walls, blocks and track pieces may sit inside a section.
		var unsupported: Array[Array] = [["the core start", level.core_start], ["the destination", level.destination]]
		for switch_def: SwitchDefinition in level.switches:
			unsupported.append(["switch '%s'" % switch_def.id, switch_def.position])
		for gate: GateDefinition in level.gates:
			unsupported.append(["gate '%s'" % gate.id, gate.position])
		for portal: PortalDefinition in level.portals:
			unsupported.append(["portal '%s'" % portal.id, portal.position])
		for route: RouteDefinition in level.routes.values():
			for checkpoint: CheckpointDefinition in route.checkpoints:
				unsupported.append(["checkpoint '%s'" % checkpoint.id, checkpoint.position])
		for item: Array in unsupported:
			if section.contains(item[1]):
				_error("%s inside rotating section '%s' is not supported yet" % [item[0], section.id])


## A segment with any node inside a section must lie wholly inside it: a track piece (D-017).
func _classify_track_pieces(level: LevelDefinition) -> void:
	for route: RouteDefinition in level.routes.values():
		var section := level.section_at(route.nodes[0])
		for node: Vector2i in route.nodes:
			if level.section_at(node) != section:
				_error("route '%s' must lie entirely inside one rotating section or entirely outside" % route.id)
				return
		if section != null:
			route.section_id = section.id
	if level.routes[level.start_route_id].section_id != "":
		_error("the start route must not be a track piece")


## Sections whose square contains a neighbour of `cell` (cell itself outside every section).
func _sections_touching(level: LevelDefinition, cell: Vector2i) -> Array[RotatingSectionDefinition]:
	var touching: Array[RotatingSectionDefinition] = []
	for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var section := level.section_at(cell + offset)
		if section != null and not touching.has(section):
			touching.append(section)
	return touching


## Validates every connection the core could ever take (D-015, D-017). Fixed segments end at the
## destination, on a portal entry (static link), or next to exactly one rotating section (dynamic link
## into a track piece). The possible-successor graph over fixed segments must reach the destination,
## reach every segment, and contain no loop, so core travel always terminates.
func _validate_route_graph(level: LevelDefinition) -> void:
	var fixed: Array[RouteDefinition] = []
	var ids: Array = level.routes.keys()
	ids.sort()
	for route_id: String in ids:
		if level.routes[route_id].section_id == "":
			fixed.append(level.routes[route_id])
	var successors: Dictionary[String, PackedStringArray] = {}
	var end_section: Dictionary[String, String] = {}
	var destination_route := ""
	for route: RouteDefinition in fixed:
		successors[route.id] = PackedStringArray()
		var last := route.nodes[route.last_index()]
		if last == level.destination:
			destination_route = route.id
			continue
		var portal := level.portal_at(last)
		if portal != null and portal.exit_id != "":
			var exit_cell := level.portal_by_id(portal.exit_id).position
			var next: RouteDefinition = null
			for candidate: RouteDefinition in fixed:
				if candidate.nodes[0] == exit_cell:
					next = candidate
			if next == null:
				_error("portal '%s' exits at %s, where no route segment starts" % [portal.id, exit_cell])
				continue
			route.exit_portal_id = portal.id
			route.next_route_id = next.id
			successors[route.id].append(next.id)
			continue
		var touching := _sections_touching(level, last)
		if touching.size() != 1:
			_error("route '%s' must end at the destination, on a portal entry, or next to one rotating section" % route.id)
			continue
		end_section[route.id] = touching[0].id
	if destination_route == "":
		_error("destination.position must be the last node of a route segment outside rotating sections")
	# Track-piece junctions: a fixed end touching section S can lead to any fixed start touching S.
	var start_cells: Dictionary[Vector2i, String] = {}
	for route: RouteDefinition in fixed:
		var start := route.nodes[0]
		for section: RotatingSectionDefinition in _sections_touching(level, start):
			for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				if section.contains(start + offset):
					if start_cells.has(start + offset):
						_error("routes '%s' and '%s' both start next to section cell %s" % [start_cells[start + offset], route.id, start + offset])
					start_cells[start + offset] = route.id
			for from_id: String in end_section.keys():
				if end_section[from_id] == section.id:
					successors[from_id].append(route.id)
	if not _errors.is_empty():
		return
	# Depth-first search from the start: detect loops, collect reachable segments.
	var reached: Dictionary[String, bool] = {}
	var on_stack: Dictionary[String, bool] = {}
	if not _visit_route(level.start_route_id, successors, reached, on_stack):
		return
	if destination_route != "" and not reached.has(destination_route):
		_error("the destination cannot be reached from the start")
	for route: RouteDefinition in fixed:
		if not reached.has(route.id):
			_error("route segment '%s' is never reached from the start" % route.id)
	for route_id: String in ids:
		var route: RouteDefinition = level.routes[route_id]
		if route.section_id != "" and not end_section.values().has(route.section_id):
			_error("track piece '%s' is never reached: no route ends next to section '%s'" % [route.id, route.section_id])


func _visit_route(route_id: String, successors: Dictionary[String, PackedStringArray],
		reached: Dictionary[String, bool], on_stack: Dictionary[String, bool]) -> bool:
	if on_stack.has(route_id):
		_error("route segments form a loop at '%s'" % route_id)
		return false
	if reached.has(route_id):
		return true
	reached[route_id] = true
	on_stack[route_id] = true
	for next_id: String in successors[route_id]:
		if not _visit_route(next_id, successors, reached, on_stack):
			return false
	on_stack.erase(route_id)
	return true


func _validate_fixture_cell(level: LevelDefinition, label: String, cell: Vector2i) -> void:
	if not level.in_bounds(cell):
		_error("%s at %s is out of bounds" % [label, cell])
	elif level.is_wall(cell):
		_error("%s at %s is inside a wall" % [label, cell])


## Every allowed mechanism must have something to act on.
func _validate_mechanism_availability(level: LevelDefinition) -> void:
	var has_toggle := false
	for switch_def: SwitchDefinition in level.switches:
		has_toggle = has_toggle or switch_def.kind == SwitchDefinition.Kind.TOGGLE
	var has_pushable := false
	for obj: MovableObject in level.initial_objects:
		has_pushable = has_pushable or obj.pushable
	var contexts: Dictionary[String, PackedStringArray] = {"setup": level.setup_allowed_mechanisms}
	for route_id: String in level.routes.keys():
		for checkpoint: CheckpointDefinition in level.routes[route_id].checkpoints:
			contexts["checkpoint '%s'" % checkpoint.id] = checkpoint.allowed_mechanisms
	for context: String in contexts.keys():
		var allowed := contexts[context]
		if allowed.has(MechanismIds.GRAVITY_SHIFT) and level.gravity_zones.is_empty():
			_error("%s allows gravity_shift but the level has no gravity zones" % context)
		if allowed.has(MechanismIds.PUSH_PULSE) and not has_pushable:
			_error("%s allows push_pulse but the level has no pushable objects" % context)
		if allowed.has(MechanismIds.SWITCHES_SEALS) and not has_toggle:
			_error("%s allows switches_seals but the level has no toggle switches" % context)


## Committed states are always stable (D-006, D-013), so the authored start must be too.
func _validate_initial_state_settled(level: LevelDefinition) -> void:
	var state := level.create_initial_state()
	for move: ObjectMove in PuzzleSimulator.stabilize(level, state, level.core_start):
		_error("object '%s' is not at rest under gravity (it would slide from %s to %s)"
			% [move.object_id, move.from_cell, move.to_cell])
	for gate_id: String in SwitchGateResolver.occupied_closed_gates(level, level.create_initial_state(), level.core_start):
		_error("gate '%s' starts closed on an occupied cell" % gate_id)


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


## Parses "up" / "right" / "down" / "left" into a Grid.Direction value.
func _direction(value: Variant, label: String) -> int:
	var direction := -1
	if typeof(value) == TYPE_STRING:
		direction = Grid.parse_direction(value)
	if direction == -1:
		_error("%s must be one of up, right, down, left" % label)
		return Grid.Direction.UP
	return direction


func _cell(value: Variant, label: String) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		_error("%s must be an [x, y] pair" % label)
		return Vector2i.ZERO
	var pair: Array = value
	return Vector2i(_int(pair[0], label + "[0]"), _int(pair[1], label + "[1]"))
