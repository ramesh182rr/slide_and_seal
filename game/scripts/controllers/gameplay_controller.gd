class_name GameplayController
extends Node
## Owns the PuzzleSession for one level and coordinates the board, input, playback and HUD.
## Every state change goes through PuzzleSession; previews use PuzzleSession.preview (same rules).
## Input is locked while a committed result is being played back.

enum TargetKind { NONE, OBJECT, ZONE, SWITCH }

## Emitted when the player confirms leaving the puzzle.
signal leave_requested
## Completion card choices; handled by AppRoot.
signal next_level_requested
signal level_select_requested
## Emitted once per completion, after the completing travel has played back (AppRoot saves it).
signal level_completed(actions: int)

@export_file("*.json") var level_path: String = "res://data/levels/world_01_slice.json"
## Skip animations (reduced motion; also used by tests).
@export var instant_playback: bool = false
## Quit the app when the player confirms leaving. AppRoot and tests turn this off and listen to
## `leave_requested` instead.
@export var quit_on_leave: bool = true
## Whether the completion card offers "Next level" (set by AppRoot from the catalog).
var next_level_available: bool = false
## Best previous result for this level (-1 = never completed), for the "New best!" note.
var previous_best_actions: int = -1
var _completion_new_best := false

@onready var _board: BoardRenderer3D = $World/Board
@onready var _camera_rig: CameraRig = $World/CameraRig
@onready var _director: AnimationDirector = $World/AnimationDirector
@onready var _input: BoardInput = $BoardInput
@onready var _hud: HudController = $HUD

var _session: PuzzleSession
var _busy := false
var _target_kind := TargetKind.NONE
var _target_id := ""


func _ready() -> void:
	var dialog := _hud.leave_dialog()
	dialog.stay_requested.connect(dialog.hide)
	dialog.leave_requested.connect(_confirm_leave)
	var loaded := LevelLoader.load_file(level_path)
	if not loaded.is_ok():
		push_error("Level failed to load: %s" % "; ".join(loaded.errors))
		_hud.show_message("This level could not be loaded.")
		_input.enabled = false
		return
	_session = PuzzleSession.new(loaded.level)
	_board.build(loaded.level, _session.get_state())
	_camera_rig.frame_board(loaded.level.board_size)
	_update_swipe_vectors()
	get_viewport().size_changed.connect(_update_swipe_vectors)
	_director.setup(_board)
	_director.instant = instant_playback
	_hud.set_title(loaded.level.title)
	_hud.run_requested.connect(func() -> void: request_action(PuzzleAction.run_core()))
	_hud.undo_requested.connect(request_undo)
	_hud.restart_requested.connect(request_restart)
	var panel := _hud.mechanism_panel()
	panel.direction_preview_started.connect(preview_target_direction)
	panel.direction_preview_ended.connect(end_preview)
	panel.direction_chosen.connect(commit_target_direction)
	panel.close_requested.connect(clear_selection)
	_hud.completion_card().next_requested.connect(func() -> void: next_level_requested.emit())
	_hud.completion_card().levels_requested.connect(func() -> void: level_select_requested.emit())
	panel.action_preview_started.connect(func() -> void: preview_target_direction(Grid.Direction.UP))
	panel.action_preview_ended.connect(end_preview)
	panel.action_chosen.connect(func() -> void: commit_target_direction(Grid.Direction.UP))
	_input.tapped.connect(_on_tapped)
	_input.swipe_previewed.connect(_on_swipe_previewed)
	_input.swipe_cancelled.connect(end_preview)
	_input.swiped.connect(_on_swiped)
	_refresh()


func get_session() -> PuzzleSession:
	return _session


func get_board() -> BoardRenderer3D:
	return _board


func get_hud() -> HudController:
	return _hud


func get_camera_rig() -> CameraRig:
	return _camera_rig


func get_board_input() -> BoardInput:
	return _input


func is_busy() -> bool:
	return _busy


## "object:<id>", "zone:<id>" or "" — for tests and debugging.
func selected_target() -> String:
	match _target_kind:
		TargetKind.OBJECT:
			return "object:" + _target_id
		TargetKind.ZONE:
			return "zone:" + _target_id
		TargetKind.SWITCH:
			return "switch:" + _target_id
	return ""


# --- Actions ------------------------------------------------------------------

## Validates and commits through the session, then plays the result back.
## Returns null (and does nothing) while a previous result is still playing.
func request_action(action: PuzzleAction) -> ActionResult:
	if _busy:
		return null
	_board.clear_preview()
	var before := _session.get_state()
	var result := _session.apply(action)
	if not result.is_ok():
		_hud.show_message(result.message)
		return result
	_hud.clear_message()
	_busy = true
	_refresh()
	_play_back(before, result)
	return result


func request_undo() -> void:
	if not _busy and _session.undo():
		_snap()


func request_restart() -> void:
	if not _busy and _session.restart():
		_snap()


# --- Back / leave ---------------------------------------------------------------

## Android Back and desktop Escape. Unwinds one layer at a time and never quits outright:
## close the leave dialog → close the mechanism panel → ask "Leave this puzzle?".
func handle_back() -> void:
	var dialog := _hud.leave_dialog()
	if dialog.visible:
		dialog.hide()
	elif _target_kind != TargetKind.NONE:
		clear_selection()
	else:
		_board.clear_preview()
		dialog.show()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()


func _confirm_leave() -> void:
	_hud.leave_dialog().hide()
	leave_requested.emit()
	if quit_on_leave:
		get_tree().quit()


# --- Selection and the mechanism panel -----------------------------------------

func select_object(object_id: String) -> void:
	var obj := _session.get_state().object_by_id(object_id)
	if obj == null:
		return
	if not obj.pushable:
		_select_none_with_message("This block cannot be pushed.")
	elif not _allowed(MechanismIds.PUSH_PULSE):
		_select_none_with_message("Push is not available here.")
	else:
		_set_target(TargetKind.OBJECT, object_id)


func select_zone(zone_id: String) -> void:
	if _session.get_level().gravity_zone(zone_id) == null:
		return
	if not _allowed(MechanismIds.GRAVITY_SHIFT):
		_select_none_with_message("Gravity cannot be changed here.")
	else:
		_set_target(TargetKind.ZONE, zone_id)


## Toggle switches open the panel; pressure plates explain themselves (they are not player-operated).
func select_switch(switch_id: String) -> void:
	var switch_def := _session.get_level().switch_by_id(switch_id)
	if switch_def == null:
		return
	var marks := _symbol_phrase(switch_id)
	if switch_def.kind == SwitchDefinition.Kind.PRESSURE:
		_select_none_with_message("Pressure plate%s: on while a block rests on it." % marks)
	elif not _allowed(MechanismIds.SWITCHES_SEALS):
		_select_none_with_message("Switches cannot be used here.")
	else:
		_set_target(TargetKind.SWITCH, switch_id)


func clear_selection() -> void:
	_set_target(TargetKind.NONE, "")


## Shows ghosts for the selected target moved in `direction`, without committing.
func preview_target_direction(direction: Grid.Direction) -> void:
	_preview(_action_for(_target_kind, _target_id, direction))


func end_preview() -> void:
	_board.clear_preview()


func commit_target_direction(direction: Grid.Direction) -> void:
	var action := _action_for(_target_kind, _target_id, direction)
	if action != null:
		request_action(action)


func _set_target(kind: TargetKind, id: String) -> void:
	_target_kind = kind
	_target_id = id
	_board.clear_preview()
	_board.set_highlight(id if kind == TargetKind.OBJECT else "", id if kind == TargetKind.ZONE else "",
		id if kind == TargetKind.SWITCH else "")
	if kind != TargetKind.NONE:
		_hud.clear_message()
	_refresh_panel()


func _select_none_with_message(message: String) -> void:
	clear_selection()
	_hud.show_message(message)


func _refresh_panel() -> void:
	var panel := _hud.mechanism_panel()
	# Drop a selection the current context no longer supports (e.g. after the core moved on).
	if _target_kind == TargetKind.OBJECT and not _allowed(MechanismIds.PUSH_PULSE) \
			or _target_kind == TargetKind.ZONE and not _allowed(MechanismIds.GRAVITY_SHIFT) \
			or _target_kind == TargetKind.SWITCH and not _allowed(MechanismIds.SWITCHES_SEALS):
		_target_kind = TargetKind.NONE
		_target_id = ""
		_board.set_highlight("", "")
	if _target_kind == TargetKind.NONE:
		panel.hide_target()
		return
	if _target_kind == TargetKind.SWITCH:
		var on: bool = _session.get_state().toggle_states[_target_id]
		panel.show_action("Switch%s · %s" % [_symbol_phrase(_target_id), "On" if on else "Off"],
			"Hold to preview, release to switch it %s." % ("off" if on else "on"),
			"Switch off" if on else "Switch on",
			not _busy and _session.preview(PuzzleAction.toggle_switch(_target_id)).is_ok())
		return
	var directions: Array[Grid.Direction] = [Grid.Direction.UP, Grid.Direction.RIGHT, Grid.Direction.DOWN, Grid.Direction.LEFT]
	var title := "%s · Push" % _display_name(_target_id)
	var hint := "Hold an arrow to preview, release to push. You can also swipe the block."
	if _target_kind == TargetKind.ZONE:
		directions = _session.get_level().gravity_zone(_target_id).allowed_directions
		title = "Gravity zone · Shift"
		hint = "Hold an arrow to preview, release to set gravity. You can also swipe the zone."
	var options: Array[Dictionary] = []
	for direction: Grid.Direction in directions:
		var action := _action_for(_target_kind, _target_id, direction)
		options.append({
			"direction": direction,
			"screen_vector": _camera_rig.screen_vector(direction),
			"enabled": not _busy and _session.preview(action).is_ok(),
		})
	panel.show_target(title, hint, options)


# --- Gestures -----------------------------------------------------------------

func _on_tapped(screen_position: Vector2) -> void:
	if _busy:
		return
	var hit := _pick(screen_position)
	var level := _session.get_level()
	if hit.object_id != "":
		select_object(hit.object_id)
	elif not hit.has_cell:
		clear_selection()
	elif _switch_at(hit.cell) != "":
		select_switch(_switch_at(hit.cell))
	elif level.gate_at(hit.cell) != null:
		var gate := level.gate_at(hit.cell)
		_select_none_with_message("Gate%s opens when every switch marked %s is on."
			% [_symbol_phrase(gate.id), _board.fixtures().symbol(gate.id)])
	elif level.portal_at(hit.cell) != null:
		var portal := level.portal_at(hit.cell)
		_select_none_with_message("Portal%s: carries the core from its entry to the matching exit." % _symbol_phrase(portal.id)
			if portal.requires.is_empty() else
			"Portal%s: works while every switch marked %s is on." % [_symbol_phrase(portal.id), _board.fixtures().symbol(portal.id)])
	elif _zone_at(hit.cell) != "":
		select_zone(_zone_at(hit.cell))
	else:
		clear_selection()


func _on_swipe_previewed(start_position: Vector2, direction: Grid.Direction) -> void:
	if _busy:
		return
	var target := _target_at(start_position)
	_preview(_action_for(target[0], target[1], direction))


func _on_swiped(start_position: Vector2, direction: Grid.Direction) -> void:
	_board.clear_preview()
	if _busy:
		return
	var target := _target_at(start_position)
	var action := _action_for(target[0], target[1], direction)
	if action != null:
		request_action(action)


## [TargetKind, id] under the pointer. Blocks take priority over the zone beneath them.
func _target_at(screen_position: Vector2) -> Array:
	var hit := _pick(screen_position)
	if hit.object_id != "":
		return [TargetKind.OBJECT, hit.object_id]
	if hit.has_cell and _zone_at(hit.cell) != "":
		return [TargetKind.ZONE, _zone_at(hit.cell)]
	return [TargetKind.NONE, ""]


func _pick(screen_position: Vector2) -> BoardPicker.Hit:
	return BoardPicker.pick(_camera_rig.get_camera(), screen_position, _session.get_level(), _session.get_state())


func _switch_at(cell: Vector2i) -> String:
	for switch_def: SwitchDefinition in _session.get_level().switches:
		if switch_def.position == cell:
			return switch_def.id
	return ""


## " A" / " 1" style suffix from the fixture's link symbol, or "".
func _symbol_phrase(fixture_id: String) -> String:
	var mark := _board.fixtures().symbol(fixture_id)
	return "" if mark == "" else " " + mark


func _zone_at(cell: Vector2i) -> String:
	for zone: GravityZoneDefinition in _session.get_level().gravity_zones:
		if zone.contains(cell):
			return zone.id
	return ""


# --- Helpers ------------------------------------------------------------------

func _action_for(kind: TargetKind, id: String, direction: Grid.Direction) -> PuzzleAction:
	match kind:
		TargetKind.OBJECT:
			return PuzzleAction.push(id, direction)
		TargetKind.ZONE:
			return PuzzleAction.set_gravity(id, direction)
		TargetKind.SWITCH:
			return PuzzleAction.toggle_switch(id)
	return null


func _preview(action: PuzzleAction) -> void:
	_board.clear_preview()
	if action == null:
		return
	var result := _session.preview(action)
	if result.is_ok():
		_hud.clear_message()
		_board.show_preview(_session.get_state(), result.state)
	else:
		_hud.show_message(result.message)


func _allowed(mechanism: String) -> bool:
	return PuzzleSimulator.allowed_mechanisms(_session.get_level(), _session.get_state()).has(mechanism)


func _play_back(before: PuzzleState, result: ActionResult) -> void:
	_input.enabled = false
	await _director.play(before, result)
	_board.sync_to_state(_session.get_state())
	_busy = false
	_input.enabled = true
	if result.state.phase == PuzzleState.Phase.LEVEL_COMPLETED and before.phase != PuzzleState.Phase.LEVEL_COMPLETED:
		var actions := result.state.mechanism_action_count
		_completion_new_best = previous_best_actions < 0 or actions < previous_best_actions
		level_completed.emit(actions)
	_refresh()


func _snap() -> void:
	_hud.clear_message()
	_board.clear_preview()
	_board.sync_to_state(_session.get_state())
	_refresh()


func _refresh() -> void:
	var state := _session.get_state()
	var can_run := _session.preview(PuzzleAction.run_core()).is_ok()
	_hud.update_view(_session.get_level(), state, can_run, _session.can_undo(),
		not _session.is_at_initial_state(), _busy)
	_hud.set_available_mechanisms(PuzzleSimulator.allowed_mechanisms(_session.get_level(), state),
		state.phase == PuzzleState.Phase.LEVEL_COMPLETED)
	_refresh_panel()
	# The card appears once the completing travel has finished playing back.
	var card := _hud.completion_card()
	if state.phase == PuzzleState.Phase.LEVEL_COMPLETED and not _busy:
		var level := _session.get_level()
		var actions := state.mechanism_action_count
		card.show_result(actions, level.target_actions,
			Progression.stars(actions, level.target_actions, level.optimal_actions), _completion_new_best,
			next_level_available)
	else:
		card.hide()


func _update_swipe_vectors() -> void:
	var vectors: Array[Vector2] = []
	for direction: int in 4:
		vectors.append(_camera_rig.screen_vector(direction as Grid.Direction))
	_input.direction_vectors = vectors


## "block_a" → "Block A".
static func _display_name(id: String) -> String:
	return id.replace("_", " ").capitalize()
