class_name MechanismPanel
extends PanelContainer
## Contextual control panel for the selected block or gravity zone.
## Arrows sit in a 3x3 grid at the position matching their on-screen direction.
## Hold an arrow to preview, release on it to commit, drag off to cancel. Emits intent only.

signal direction_preview_started(direction: Grid.Direction)
signal direction_preview_ended
signal direction_chosen(direction: Grid.Direction)
signal close_requested

const CELL_SIZE := Vector2(150, 118)

var _title := Label.new()
var _hint := Label.new()
var _grid := GridContainer.new()
var _buttons: Dictionary[int, ArrowButton] = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.NAVY_SURFACE, 0.94)
	style.border_color = Palette.MECHANISM_AMBER.darkened(0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Palette.MECHANISM_AMBER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_grid)


## `options`: one Dictionary per offered direction with keys
## direction (Grid.Direction), screen_vector (Vector2), enabled (bool).
func show_target(title: String, hint: String, options: Array[Dictionary]) -> void:
	_title.text = title
	_hint.text = hint
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.free()
	_buttons.clear()
	var slots: Array[Control] = []
	slots.resize(9)
	for option: Dictionary in options:
		var direction: Grid.Direction = option["direction"]
		var vector: Vector2 = option["screen_vector"]
		var button := ArrowButton.new()
		button.custom_minimum_size = CELL_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.screen_angle = vector.angle()
		button.disabled = not option["enabled"]
		button.button_down.connect(func() -> void: direction_preview_started.emit(direction))
		button.button_up.connect(func() -> void: direction_preview_ended.emit())
		button.pressed.connect(func() -> void: direction_chosen.emit(direction))
		slots[slot_index(vector)] = button
		_buttons[direction] = button
	# Collapse the middle row/column when no arrow uses them (e.g. diagonal-only isometric arrows).
	var middle_row_used := slots[3] != null or slots[4] != null or slots[5] != null
	var middle_column_used := slots[1] != null or slots[4] != null or slots[7] != null
	for i: int in 9:
		var slot := slots[i]
		if slot == null:
			slot = Control.new()
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.custom_minimum_size = Vector2(
				CELL_SIZE.x if middle_column_used or i % 3 != 1 else 16.0,
				CELL_SIZE.y if middle_row_used or i / 3 != 1 else 8.0)
		_grid.add_child(slot)
	visible = true


func hide_target() -> void:
	visible = false


func has_option(direction: Grid.Direction) -> bool:
	return _buttons.has(direction)


func is_option_enabled(direction: Grid.Direction) -> bool:
	return _buttons.has(direction) and not _buttons[direction].disabled


func title_text() -> String:
	return _title.text


## 3x3 slot (row-major) whose position matches the vector's on-screen direction.
static func slot_index(vector: Vector2) -> int:
	var column := 1 if absf(vector.x) < 0.38 else (2 if vector.x > 0.0 else 0)
	var row := 1 if absf(vector.y) < 0.38 else (2 if vector.y > 0.0 else 0)
	return row * 3 + column
