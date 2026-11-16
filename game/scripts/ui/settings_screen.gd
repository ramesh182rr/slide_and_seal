class_name SettingsScreen
extends Control
## Settings (P-019): reduced motion and reset progress. Emits intent; AppRoot applies and saves.

signal back_requested
signal reduced_motion_changed(enabled: bool)
signal haptics_changed(enabled: bool)
signal reset_progress_confirmed

const MARGIN := 48

## A toggle button with an explicit On/Off label (the default switch icon is unreadably small).
var _reduced_motion := Button.new()
var _reduced_motion_state := Label.new()
var _reset := Button.new()
var _status := Label.new()
var _confirm_reset := ConfirmDialog.new()
var _margin := MarginContainer.new()
var _initial_reduced_motion := false
var _initial_haptics := true
var _haptics := Button.new()
var _haptics_state := Label.new()


func setup(reduced_motion: bool, haptics: bool = true) -> void:
	_initial_reduced_motion = reduced_motion
	_initial_haptics = haptics


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make_theme()
	var background := ColorRect.new()
	background.color = Palette.DEEP_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	_margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_theme_constant_override("separation", 20)
	var back := IconButton.new(IconButton.Icon.BACK)
	back.custom_minimum_size = Vector2(96, 96)
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)
	var title := Label.new()
	title.text = "SETTINGS"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_title(title, 48, Palette.TEXT)
	header.add_child(title)

	_section(column, "Accessibility")
	_reduced_motion.toggle_mode = true
	_reduced_motion.custom_minimum_size = Vector2(0, 110)
	_reduced_motion.focus_mode = Control.FOCUS_NONE
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced_motion.add_child(row)
	var name_label := Label.new()
	name_label.text = "   Reduced motion"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_label(name_label, 34, Palette.TEXT)
	row.add_child(name_label)
	_reduced_motion_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_reduced_motion_state)
	_reduced_motion.button_pressed = _initial_reduced_motion
	_show_reduced_motion_state(_initial_reduced_motion)
	_reduced_motion.toggled.connect(func(enabled: bool) -> void:
		_show_reduced_motion_state(enabled)
		reduced_motion_changed.emit(enabled))
	column.add_child(_reduced_motion)
	_note(column, "Skips animations: every move appears instantly.")

	_section(column, "Feedback")
	_haptics.toggle_mode = true
	_haptics.custom_minimum_size = Vector2(0, 110)
	_haptics.focus_mode = Control.FOCUS_NONE
	var haptics_row := HBoxContainer.new()
	haptics_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haptics_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haptics.add_child(haptics_row)
	var haptics_name := Label.new()
	haptics_name.text = "   Vibration"
	haptics_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haptics_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_label(haptics_name, 34, Palette.TEXT)
	haptics_row.add_child(haptics_name)
	_haptics_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	haptics_row.add_child(_haptics_state)
	_haptics.button_pressed = _initial_haptics
	_show_toggle_state(_haptics_state, _initial_haptics)
	_haptics.toggled.connect(func(enabled: bool) -> void:
		_show_toggle_state(_haptics_state, enabled)
		haptics_changed.emit(enabled))
	column.add_child(_haptics)
	_note(column, "A short tick when you make a move or complete a seal.")

	_section(column, "Progress")
	_reset.text = "Reset progress"
	_reset.custom_minimum_size = Vector2(0, 110)
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.add_theme_stylebox_override("normal", UiTheme.box(Palette.NAVY_SURFACE, Palette.POLARITY_RED))
	_reset.add_theme_stylebox_override("hover", UiTheme.box(Palette.NAVY_SURFACE.lightened(0.08), Palette.POLARITY_RED))
	_reset.pressed.connect(func() -> void: _confirm_reset.show())
	column.add_child(_reset)
	_note(column, "Erases completed levels, best results and stars. Settings are kept.")
	UiTheme.style_label(_status, 30, Palette.MINT_SUCCESS)
	column.add_child(_status)

	_confirm_reset.setup("Reset all progress?",
		"Completed levels, best results and stars will be erased. This cannot be undone.", "Cancel", "Reset")
	_confirm_reset.cancelled.connect(func() -> void: _confirm_reset.hide())
	_confirm_reset.confirmed.connect(_on_reset_confirmed)
	add_child(_confirm_reset)


## Back unwinds the confirmation first. Returns true if it was handled here.
func handle_back() -> bool:
	if _confirm_reset.visible:
		_confirm_reset.hide()
		return true
	return false


# Accessors for tests.
func haptics_toggle() -> Button:
	return _haptics


func reduced_motion_toggle() -> Button:
	return _reduced_motion


func reduced_motion_state_text() -> String:
	return _reduced_motion_state.text


func reset_button() -> Button:
	return _reset


func reset_dialog() -> ConfirmDialog:
	return _confirm_reset


func status_text() -> String:
	return _status.text


func _show_reduced_motion_state(enabled: bool) -> void:
	_reduced_motion_state.text = "On   " if enabled else "Off   "
	UiTheme.style_label(_reduced_motion_state, 34, Palette.MINT_SUCCESS if enabled else Palette.TEXT_MUTED)


func _show_toggle_state(label: Label, enabled: bool) -> void:
	label.text = "On   " if enabled else "Off   "
	UiTheme.style_label(label, 34, Palette.MINT_SUCCESS if enabled else Palette.TEXT_MUTED)


func _on_reset_confirmed() -> void:
	_confirm_reset.hide()
	reset_progress_confirmed.emit()
	_status.text = "Progress reset."


func _section(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	UiTheme.style_label(label, 36, Palette.MECHANISM_AMBER)
	column.add_child(label)


func _note(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_label(label, 26, Palette.TEXT_MUTED)
	column.add_child(label)


func _apply_safe_area() -> void:
	UiTheme.apply_safe_margins(_margin, MARGIN)
