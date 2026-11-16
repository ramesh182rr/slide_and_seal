class_name HudController
extends CanvasLayer
## Gameplay HUD: level title, status, action counter, message line, and Undo / Restart / Run.
## Emits requests only; it never changes puzzle state. Placeholder styling (D-011) using
## the doc 06 palette. Non-interactive areas ignore the mouse so board taps pass through (M3b).

signal run_requested
signal undo_requested
signal restart_requested
## The on-screen Back button (top left), the same way out as the system Back gesture.
signal back_requested
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
var _world := Label.new()
var _status := Label.new()
var _actions := Label.new()
var _available := Label.new()
var _message := Label.new()
var _panel := MechanismPanel.new()
var _completion := CompletionCard.new()
var _undo := IconButton.new(IconButton.Icon.UNDO)
var _restart := IconButton.new(IconButton.Icon.RESTART)
var _run := IconButton.new(IconButton.Icon.PLAY, "Run")
var _back := IconButton.new(IconButton.Icon.BACK)
var _margin := MarginContainer.new()
var _leave_dialog := LeaveDialog.new()
var _view_buttons: Dictionary[IconButton.Icon, IconButton] = {}
var _top_bar := PanelContainer.new()


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
	column.add_theme_constant_override("separation", 14)
	_margin.add_child(column)
	_build_view_controls()

	# Top bar: Back · world / level title · Undo · Restart.
	_top_bar.add_theme_stylebox_override("panel", _bar_style(Palette.CYAN_ENERGY))
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_top_bar)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 18)
	_top_bar.add_child(header)
	_back.custom_minimum_size = Vector2(96, 96)
	_back.tooltip_text = "Back"
	_back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(_back)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	UiTheme.style_label(_world, 24, Palette.TEXT_MUTED)
	_world.uppercase = true
	_world.add_theme_constant_override("line_spacing", 0)
	titles.add_child(_world)
	UiTheme.style_title(_title, 36, Palette.TEXT)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	titles.add_child(_title)
	# Move counter: "3 / 5" under a small caption, in the bar (no separate status box).
	var counter := VBoxContainer.new()
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.alignment = BoxContainer.ALIGNMENT_CENTER
	counter.add_theme_constant_override("separation", -4)
	header.add_child(counter)
	var caption := Label.new()
	caption.text = "MOVES"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_label(caption, 20, Palette.TEXT_MUTED)
	counter.add_child(caption)
	UiTheme.style_label(_actions, 34, Palette.TEXT)
	_actions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions.custom_minimum_size = Vector2(120, 0)
	counter.add_child(_actions)
	for entry: Array in [[_undo, "Undo", undo_requested], [_restart, "Restart", restart_requested]]:
		var button: IconButton = entry[0]
		button.custom_minimum_size = Vector2(96, 96)
		button.tooltip_text = entry[1]
		var request: Signal = entry[2]
		button.pressed.connect(func() -> void: request.emit())
		header.add_child(button)

	# One slim hint line under the bar; what can be used appears only when there is something.
	for label: Label in [_status, _available]:
		label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.07, 0.85))
		label.add_theme_constant_override("outline_size", 10)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	UiTheme.style_label(_status, 28, Palette.CYAN_ENERGY.lightened(0.25))
	UiTheme.style_label(_available, 26, Palette.MECHANISM_AMBER)
	_available.visible = false

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	UiTheme.style_label(_message, 30, Palette.MECHANISM_AMBER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_message.add_theme_constant_override("outline_size", 10)
	column.add_child(_message)
	column.add_child(_panel)
	column.add_child(_completion)

	_run.custom_minimum_size = Vector2(0, 128)
	_run.add_theme_font_size_override("font_size", 40)
	_run.pressed.connect(func() -> void: run_requested.emit())
	UiTheme.make_primary(_run)
	column.add_child(_run)
	# Last child of the root so it draws above, and captures input over, everything else.
	root.add_child(_leave_dialog)


static func _bar_style(accent: Color) -> StyleBoxFlat:
	var style := UiTheme.panel(accent, 30)
	style.set_content_margin_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style


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
		button.modulate.a = 0.7
		button.pressed.connect(spec[1] as Callable)
		cluster.add_child(button)
		_view_buttons[spec[0] as IconButton.Icon] = button


## The world's name and signature colour (top bar border, world label).
func set_world(world_theme: WorldTheme) -> void:
	_world.text = world_theme.title
	_world.add_theme_color_override("font_color", world_theme.accent.lightened(0.2))
	_top_bar.add_theme_stylebox_override("panel", _bar_style(world_theme.accent))


func back_button() -> Button:
	return _back


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
	# The empty-list reminder duplicates the hint line, so it stays off screen.
	_available.visible = not completed and not mechanisms.is_empty()


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
	_actions.text = "%d / %d" % [state.mechanism_action_count, level.target_actions]
	# Over target: the count turns amber (the number itself still tells the story).
	_actions.add_theme_color_override("font_color",
		Palette.MECHANISM_AMBER if state.mechanism_action_count > level.target_actions else Palette.TEXT)
	_run.text = "Run" if state.phase == PuzzleState.Phase.SETUP else "Resume"
	_run.disabled = locked or not can_run
	_run.visible = state.phase != PuzzleState.Phase.LEVEL_COMPLETED  # The completion card takes over.
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
