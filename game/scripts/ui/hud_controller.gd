class_name HudController
extends CanvasLayer
## Gameplay HUD: level title, status, action counter, message line, and Undo / Restart / Run.
## Emits requests only; it never changes puzzle state. Placeholder styling (D-011) using
## the doc 06 palette. Non-interactive areas ignore the mouse so board taps pass through (M3b).

signal run_requested
signal undo_requested
signal restart_requested
## View controls (D-032): presentation only.
signal view_turn_requested(clockwise: bool)
signal view_zoom_requested(factor: float)
signal view_reset_requested

const MARGIN := 48
const VIEW_BUTTON_SIZE := 84.0
const VIEW_ZOOM_STEP := 1.25

const MECHANISM_LABELS := {
	MechanismIds.PUSH_PULSE: "Push",
	MechanismIds.GRAVITY_SHIFT: "Gravity",
	MechanismIds.SWITCHES_SEALS: "Switches",
	MechanismIds.ROTATING_SECTIONS: "Rotation",
	MechanismIds.ENERGY_ROUTING: "Energy",
	MechanismIds.MAGNETIC_POLARITY: "Magnetism",
}

var _title := Label.new()
var _status := Label.new()
var _actions := Label.new()
var _available := Label.new()
var _message := Label.new()
var _panel := MechanismPanel.new()
var _completion := CompletionCard.new()
var _undo := Button.new()
var _restart := Button.new()
var _run := Button.new()
var _margin := MarginContainer.new()
var _leave_dialog := LeaveDialog.new()
var _view_buttons: Dictionary[IconButton.Icon, IconButton] = {}


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make_theme()
	add_child(root)

	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_margin)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	_margin.add_child(column)
	_build_view_controls()

	UiTheme.style_label(_title, 44, Palette.TEXT)
	UiTheme.style_label(_status, 32, Palette.CYAN_ENERGY)
	UiTheme.style_label(_actions, 28, Palette.TEXT_MUTED)
	UiTheme.style_label(_available, 28, Palette.MECHANISM_AMBER)
	for label: Label in [_title, _status, _actions, _available]:
		column.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	UiTheme.style_label(_message, 30, Palette.MECHANISM_AMBER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	column.add_child(_panel)
	column.add_child(_completion)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(buttons)
	_setup_button(_undo, "Undo", undo_requested)
	_setup_button(_restart, "Restart", restart_requested)
	_setup_button(_run, "Run", run_requested)
	_run.size_flags_stretch_ratio = 1.6
	UiTheme.make_primary(_run)
	for button: Button in [_undo, _restart, _run]:
		buttons.add_child(button)
	# Last child of the root so it draws above, and captures input over, everything else.
	root.add_child(_leave_dialog)


## A slim vertical cluster on the right edge, centred on the board band. Only the buttons take
## input; the gaps between them pass touches through to the board.
func _build_view_controls() -> void:
	var cluster := VBoxContainer.new()
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.add_theme_constant_override("separation", 10)
	cluster.size_flags_horizontal = Control.SIZE_SHRINK_END
	cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_margin.add_child(cluster)
	var specs: Array[Array] = [
		[IconButton.Icon.ROTATE_LEFT, func() -> void: view_turn_requested.emit(false)],
		[IconButton.Icon.ROTATE_RIGHT, func() -> void: view_turn_requested.emit(true)],
		[IconButton.Icon.ZOOM_IN, func() -> void: view_zoom_requested.emit(VIEW_ZOOM_STEP)],
		[IconButton.Icon.ZOOM_OUT, func() -> void: view_zoom_requested.emit(1.0 / VIEW_ZOOM_STEP)],
		[IconButton.Icon.RESET_VIEW, func() -> void: view_reset_requested.emit()],
	]
	for spec: Array in specs:
		var button := IconButton.new(spec[0] as IconButton.Icon)
		button.custom_minimum_size = Vector2(VIEW_BUTTON_SIZE, VIEW_BUTTON_SIZE)
		button.modulate.a = 0.85
		button.pressed.connect(spec[1] as Callable)
		cluster.add_child(button)
		_view_buttons[spec[0] as IconButton.Icon] = button


func view_button(icon: IconButton.Icon) -> IconButton:
	return _view_buttons[icon]


func set_title(text: String) -> void:
	_title.text = text


func mechanism_panel() -> MechanismPanel:
	return _panel


func completion_card() -> CompletionCard:
	return _completion


func leave_dialog() -> LeaveDialog:
	return _leave_dialog


## Lists what the player may use right now (from PuzzleSimulator.allowed_mechanisms).
func set_available_mechanisms(mechanisms: PackedStringArray, completed: bool) -> void:
	if completed:
		_available.text = ""
	elif mechanisms.is_empty():
		_available.text = "No mechanisms here: run the core."
	else:
		var names := PackedStringArray()
		for mechanism: String in mechanisms:
			names.append(MECHANISM_LABELS.get(mechanism, mechanism))
		_available.text = "Available: %s. %s." % [", ".join(names), _how_to(mechanisms)]


func available_text() -> String:
	return _available.text


## "Tap or swipe a block", "Tap a switch", or both joined. Switches and sections are tap-only.
static func _how_to(mechanisms: PackedStringArray) -> String:
	var swipeable := PackedStringArray()
	if mechanisms.has(MechanismIds.PUSH_PULSE):
		swipeable.append("block")
	if mechanisms.has(MechanismIds.GRAVITY_SHIFT):
		swipeable.append("gravity zone")
	var parts := PackedStringArray()
	if not swipeable.is_empty():
		parts.append("Tap or swipe a " + " or ".join(swipeable))
	var tap_only := PackedStringArray()
	if mechanisms.has(MechanismIds.SWITCHES_SEALS):
		tap_only.append("switch")
	if mechanisms.has(MechanismIds.ROTATING_SECTIONS):
		tap_only.append("rotating section")
	if mechanisms.has(MechanismIds.ENERGY_ROUTING):
		tap_only.append("mirror")
	if mechanisms.has(MechanismIds.MAGNETIC_POLARITY):
		tap_only.append("magnet")
	if not tap_only.is_empty():
		var phrase := "a " + " or ".join(tap_only)
		parts.append(("tap " if not parts.is_empty() else "Tap ") + phrase)
	return "; ".join(parts)


## Keeps content clear of notches and system bars on mobile.
func _apply_safe_area() -> void:
	UiTheme.apply_safe_margins(_margin, MARGIN)


## Reflects the committed state. Availability flags come from the simulation via the controller.
func update_view(level: LevelDefinition, state: PuzzleState, can_run: bool, can_undo: bool,
		can_restart: bool, locked: bool) -> void:
	_status.text = _phase_text(state.phase)
	_actions.text = "Actions %d  ·  Target %d" % [state.mechanism_action_count, level.target_actions]
	_run.text = "Run" if state.phase == PuzzleState.Phase.SETUP else "Resume"
	_run.disabled = locked or not can_run
	_undo.disabled = locked or not can_undo
	_restart.disabled = locked or not can_restart


func show_message(text: String) -> void:
	_message.text = text


func clear_message() -> void:
	_message.text = ""


# Read-only accessors for tests.
func status_text() -> String:
	return _status.text


func message_text() -> String:
	return _message.text


func run_label() -> String:
	return _run.text


func is_run_enabled() -> bool:
	return not _run.disabled


func is_undo_enabled() -> bool:
	return not _undo.disabled


func is_restart_enabled() -> bool:
	return not _restart.disabled


static func _phase_text(phase: PuzzleState.Phase) -> String:
	match phase:
		PuzzleState.Phase.SETUP:
			return "Study the maze, then run the core."
		PuzzleState.Phase.CHECKPOINT_PAUSED:
			return "Checkpoint: adjust the maze, then resume."
		PuzzleState.Phase.BLOCKED_WAITING_FOR_ACTION:
			return "The path is blocked: change the maze."
		PuzzleState.Phase.LEVEL_COMPLETED:
			return "Seal complete."
	return ""


func _setup_button(button: Button, text: String, request: Signal) -> void:
	button.text = text
	button.custom_minimum_size = Vector2(0, 110)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: request.emit())
