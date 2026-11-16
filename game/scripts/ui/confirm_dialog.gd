class_name ConfirmDialog
extends Control
## Modal confirmation with a full-screen dimmer that swallows input behind it.
## Configure with setup() before adding to the tree; show()/hide() to use.

signal cancelled
signal confirmed

var _title := "Are you sure?"
var _body := ""
var _cancel_text := "Cancel"
var _confirm_text := "Confirm"
var _cancel := Button.new()
var _confirm := Button.new()


func setup(title: String, body: String, cancel_text: String, confirm_text: String) -> void:
	_title = title
	_body = body
	_cancel_text = cancel_text
	_confirm_text = confirm_text


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
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Palette.CYAN_ENERGY))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var title := Label.new()
	title.text = _title
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_label(title, 44, Palette.TEXT)
	column.add_child(title)
	if _body != "":
		var body := Label.new()
		body.text = _body
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.style_label(body, 30, Palette.TEXT_MUTED)
		column.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	for entry: Array in [[_cancel, _cancel_text, cancelled], [_confirm, _confirm_text, confirmed]]:
		var button: Button = entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(0, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		var request: Signal = entry[2]
		button.pressed.connect(func() -> void: request.emit())
		buttons.add_child(button)


func confirm_button() -> Button:
	return _confirm


func cancel_button() -> Button:
	return _cancel
