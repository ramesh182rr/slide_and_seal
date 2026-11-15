class_name HudController
extends CanvasLayer
## Gameplay HUD: level title, status, action counter, message line, and Undo / Restart / Run.
## Emits requests only; it never changes puzzle state. Placeholder styling (D-011) using
## the doc 06 palette. Non-interactive areas ignore the mouse so board taps pass through (M3b).

signal run_requested
signal undo_requested
signal restart_requested

const MARGIN := 48

const MECHANISM_LABELS := {
	MechanismIds.PUSH_PULSE: "Push",
	MechanismIds.GRAVITY_SHIFT: "Gravity",
	MechanismIds.SWITCHES_SEALS: "Switches",
}

var _title := Label.new()
var _status := Label.new()
var _actions := Label.new()
var _available := Label.new()
var _message := Label.new()
var _panel := MechanismPanel.new()
var _undo := Button.new()
var _restart := Button.new()
var _run := Button.new()
var _margin := MarginContainer.new()
var _leave_dialog := LeaveDialog.new()


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
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

	_style_label(_title, 44, Palette.TEXT)
	_style_label(_status, 32, Palette.CYAN_ENERGY)
	_style_label(_actions, 28, Palette.TEXT_MUTED)
	_style_label(_available, 28, Palette.MECHANISM_AMBER)
	for label: Label in [_title, _status, _actions, _available]:
		column.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_style_label(_message, 30, Palette.MECHANISM_AMBER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	column.add_child(_panel)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(buttons)
	_setup_button(_undo, "Undo", undo_requested)
	_setup_button(_restart, "Restart", restart_requested)
	_setup_button(_run, "Run", run_requested)
	_run.size_flags_stretch_ratio = 1.6
	_run.add_theme_stylebox_override("normal", _box(Palette.NAVY_SURFACE, Palette.MINT_SUCCESS))
	_run.add_theme_stylebox_override("hover", _box(Palette.NAVY_SURFACE.lightened(0.08), Palette.MINT_SUCCESS))
	for button: Button in [_undo, _restart, _run]:
		buttons.add_child(button)
	# Last child of the root so it draws above, and captures input over, everything else.
	root.add_child(_leave_dialog)


func set_title(text: String) -> void:
	_title.text = text


func mechanism_panel() -> MechanismPanel:
	return _panel


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


## "Tap or swipe a block", "Tap a switch", or both joined. Switches are tap-only.
static func _how_to(mechanisms: PackedStringArray) -> String:
	var swipeable := PackedStringArray()
	if mechanisms.has(MechanismIds.PUSH_PULSE):
		swipeable.append("block")
	if mechanisms.has(MechanismIds.GRAVITY_SHIFT):
		swipeable.append("gravity zone")
	var parts := PackedStringArray()
	if not swipeable.is_empty():
		parts.append("Tap or swipe a " + " or ".join(swipeable))
	if mechanisms.has(MechanismIds.SWITCHES_SEALS):
		parts.append("tap a switch" if not parts.is_empty() else "Tap a switch")
	return "; ".join(parts)


## Keeps content clear of notches and system bars on mobile. Desktop uses fixed margins:
## the display safe area there describes the screen, not the window.
func _apply_safe_area() -> void:
	var insets := [0.0, 0.0, 0.0, 0.0]  # left, top, right, bottom in viewport pixels
	if OS.has_feature("mobile"):
		var screen := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		var scale := get_viewport().get_visible_rect().size.x / maxf(screen.x, 1.0)
		insets = [safe.position.x * scale, safe.position.y * scale,
			(screen.x - safe.end.x) * scale, (screen.y - safe.end.y) * scale]
	var sides := ["left", "top", "right", "bottom"]
	for i: int in 4:
		_margin.add_theme_constant_override("margin_" + sides[i], MARGIN + int(insets[i]))


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


static func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 34
	theme.set_stylebox("normal", "Button", _box(Palette.NAVY_SURFACE, Palette.CYAN_ENERGY.darkened(0.35)))
	theme.set_stylebox("hover", "Button", _box(Palette.NAVY_SURFACE.lightened(0.08), Palette.CYAN_ENERGY))
	theme.set_stylebox("pressed", "Button", _box(Palette.BOARD_SLATE, Palette.CYAN_ENERGY))
	theme.set_stylebox("disabled", "Button", _box(Palette.DEEP_BACKGROUND, Palette.BOARD_SLATE))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.TEXT)
	theme.set_color("font_pressed_color", "Button", Palette.TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_MUTED.darkened(0.3))
	return theme


static func _box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(22)
	box.set_content_margin_all(20)
	return box
