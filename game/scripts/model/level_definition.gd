class_name LevelDefinition
extends RefCounted
## Authored level data produced by LevelLoader. Treated as immutable at runtime.

var schema_version: int = 0
var id: String = ""
var title: String = ""
var world_id: String = ""
var access: String = ""
var board_size: Vector2i = Vector2i.ZERO
## Set of wall cells (values are always true).
var walls: Dictionary[Vector2i, bool] = {}
var routes: Dictionary[String, RouteDefinition] = {}
var start_route_id: String = ""
var core_start: Vector2i = Vector2i.ZERO
var destination: Vector2i = Vector2i.ZERO
var seal_id: String = ""
## Sorted by id.
var initial_objects: Array[MovableObject] = []
## Sorted by id. Never overlapping.
var gravity_zones: Array[GravityZoneDefinition] = []
## Sorted by id.
var switches: Array[SwitchDefinition] = []
## Sorted by id.
var gates: Array[GateDefinition] = []
## Sorted by id.
var portals: Array[PortalDefinition] = []
## Sorted by id. Never overlapping.
var rotating_sections: Array[RotatingSectionDefinition] = []
## Sorted by id.
var emitters: Array[EmitterDefinition] = []
## Sorted by id.
var reflectors: Array[ReflectorDefinition] = []
## Sorted by id.
var magnets: Array[MagnetDefinition] = []
## Mechanisms usable before the first run (D-008).
var setup_allowed_mechanisms: PackedStringArray = PackedStringArray()
var target_actions: int = 0
## -1 when no solver-proven optimum exists.
var optimal_actions: int = -1


func in_bounds(cell: Vector2i) -> bool:
	return Grid.in_bounds(cell, board_size)


func is_wall(cell: Vector2i) -> bool:
	return walls.has(cell)


func gravity_zone(zone_id: String) -> GravityZoneDefinition:
	for zone: GravityZoneDefinition in gravity_zones:
		if zone.id == zone_id:
			return zone
	return null


func switch_by_id(switch_id: String) -> SwitchDefinition:
	for switch_def: SwitchDefinition in switches:
		if switch_def.id == switch_id:
			return switch_def
	return null


func gate_at(cell: Vector2i) -> GateDefinition:
	for gate: GateDefinition in gates:
		if gate.position == cell:
			return gate
	return null


func emitter_at(cell: Vector2i) -> EmitterDefinition:
	for emitter: EmitterDefinition in emitters:
		if emitter.position == cell:
			return emitter
	return null


func reflector_at(cell: Vector2i) -> ReflectorDefinition:
	for reflector: ReflectorDefinition in reflectors:
		if reflector.position == cell:
			return reflector
	return null


func reflector_by_id(reflector_id: String) -> ReflectorDefinition:
	for reflector: ReflectorDefinition in reflectors:
		if reflector.id == reflector_id:
			return reflector
	return null


func receiver_at(cell: Vector2i) -> SwitchDefinition:
	for switch_def: SwitchDefinition in switches:
		if switch_def.kind == SwitchDefinition.Kind.RECEIVER and switch_def.position == cell:
			return switch_def
	return null


func magnet_by_id(magnet_id: String) -> MagnetDefinition:
	for magnet: MagnetDefinition in magnets:
		if magnet.id == magnet_id:
			return magnet
	return null


func magnet_at(cell: Vector2i) -> MagnetDefinition:
	for magnet: MagnetDefinition in magnets:
		if magnet.position == cell:
			return magnet
	return null


## Emitters, reflectors and magnets are solid fixtures: blocks and the core cannot enter them.
## (Beams pass reflectors and stop at emitters; magnets stop beams as walls do.)
func is_solid_fixture(cell: Vector2i) -> bool:
	return emitter_at(cell) != null or reflector_at(cell) != null or magnet_at(cell) != null


func rotating_section(section_id: String) -> RotatingSectionDefinition:
	for section: RotatingSectionDefinition in rotating_sections:
		if section.id == section_id:
			return section
	return null


func section_at(cell: Vector2i) -> RotatingSectionDefinition:
	for section: RotatingSectionDefinition in rotating_sections:
		if section.contains(cell):
			return section
	return null


func portal_by_id(portal_id: String) -> PortalDefinition:
	for portal: PortalDefinition in portals:
		if portal.id == portal_id:
			return portal
	return null


func portal_at(cell: Vector2i) -> PortalDefinition:
	for portal: PortalDefinition in portals:
		if portal.position == cell:
			return portal
	return null


func checkpoint_by_id(checkpoint_id: String) -> CheckpointDefinition:
	for route: RouteDefinition in routes.values():
		for checkpoint: CheckpointDefinition in route.checkpoints:
			if checkpoint.id == checkpoint_id:
				return checkpoint
	return null


## Returns a fresh copy of the exact authored starting state.
func create_initial_state() -> PuzzleState:
	var state := PuzzleState.new()
	state.phase = PuzzleState.Phase.SETUP
	state.core_route_id = start_route_id
	state.core_node_index = 0
	for obj: MovableObject in initial_objects:
		state.objects.append(obj.clone())
	state.sort_objects()
	for zone: GravityZoneDefinition in gravity_zones:
		state.gravity_directions[zone.id] = zone.initial_direction
	for switch_def: SwitchDefinition in switches:
		if switch_def.kind == SwitchDefinition.Kind.TOGGLE:
			state.toggle_states[switch_def.id] = switch_def.initially_on
	for section: RotatingSectionDefinition in rotating_sections:
		state.section_turns[section.id] = 0
	for reflector: ReflectorDefinition in reflectors:
		state.reflector_slash[reflector.id] = reflector.initially_slash
	for magnet: MagnetDefinition in magnets:
		state.magnet_positive[magnet.id] = magnet.initially_positive
	EnergyResolver.update_power(self, state)
	return state
