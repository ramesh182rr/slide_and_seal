class_name LeaveDialog
extends Control
## Modal "Leave this puzzle?" confirmation shown for Android Back / Escape.
## A full-screen dimmer swallows input so nothing behind it can be touched while it is open.

signal stay_requested
signal leave_requested


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dimmer := ColorRect.new()
	dimmer.color = Color(Palette.DEEP_BACKGROUND, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.NAVY_SURFACE
	style.border_color = Palette.CYAN_ENERGY.darkened(0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Leave this puzzle?"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Palette.TEXT)
	column.add_child(title)
	var body := Label.new()
	body.text = "Your progress in this puzzle will be lost."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 30)
	body.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	column.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	for entry: Array in [["Stay", stay_requested], ["Leave", leave_requested]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(0, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		var request: Signal = entry[1]
		button.pressed.connect(func() -> void: request.emit())
		buttons.add_child(button)
