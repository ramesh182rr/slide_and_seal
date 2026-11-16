class_name MechanismPanel
extends PanelContainer
## Contextual control panel for the selected block or gravity zone.
## Arrows sit in a 3x3 grid at the position matching their on-screen direction.
## Hold an arrow to preview, release on it to commit, drag off to cancel. Emits intent only.
## The nine slot buttons are created once and reconfigured in place: committing from an arrow's
## own `pressed` signal refreshes this panel, so freeing buttons here would free the emitter.

signal direction_preview_started(direction: Grid.Direction)
signal direction_preview_ended
signal direction_chosen(direction: Grid.Direction)
signal close_requested
## Action mode (toggling a switch, turning a section): one or two buttons with the same
## hold-to-preview / release-to-commit pattern. `index` is the button's position in `show_actions`.
signal action_preview_started(index: int)
signal action_preview_ended
signal action_chosen(index: int)

const MAX_ACTIONS := 2

const CELL_SIZE := Vector2(150, 118)
## Size of an unused middle row/column, so diagonal-only layouts stay compact.
const COLLAPSED_SIZE := Vector2(16, 8)

var _title := Label.new()
var _hint := Label.new()
var _grid := GridContainer.new()
var _slots: Array[ArrowButton] = []
## Direction shown in each slot, or -1 when the slot is empty.
var _slot_directions := PackedInt32Array()
var _buttons: Dictionary[int, ArrowButton] = {}
var _action_row := HBoxContainer.new()
var _action_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.NAVY_SURFACE, 0.94)
	style.border_color = Palette.MECHANISM_AMBER.darkened(0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", UiTheme.panel(Palette.MECHANISM_AMBER))

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

	_action_row.add_theme_constant_override("separation", 16)
	_action_row.visible = false
	column.add_child(_action_row)
	for i: int in MAX_ACTIONS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(func() -> void: action_preview_started.emit(i))
		button.button_up.connect(func() -> void: action_preview_ended.emit())
		button.pressed.connect(func() -> void: action_chosen.emit(i))
		_action_row.add_child(button)
		_action_buttons.append(button)

	for i: int in 9:
		var button := ArrowButton.new()
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(_on_slot_down.bind(i))
		button.button_up.connect(_on_slot_up.bind(i))
		button.pressed.connect(_on_slot_pressed.bind(i))
		_grid.add_child(button)
		_slots.append(button)
		_slot_directions.append(-1)


## `options`: one Dictionary per offered direction with keys
## direction (Grid.Direction), screen_vector (Vector2), enabled (bool).
func show_target(title: String, hint: String, options: Array[Dictionary]) -> void:
	_title.text = title
	_hint.text = hint
	_grid.visible = true
	_action_row.visible = false
	_buttons.clear()
	_slot_directions.fill(-1)
	for option: Dictionary in options:
		var vector: Vector2 = option["screen_vector"]
		var slot := slot_index(vector)
		var button := _slots[slot]
		_slot_directions[slot] = option["direction"]
		button.screen_angle = vector.angle()
		button.disabled = not option["enabled"]
		_buttons[option["direction"]] = button
	var middle_row_used := _slot_directions[3] >= 0 or _slot_directions[4] >= 0 or _slot_directions[5] >= 0
	var middle_column_used := _slot_directions[1] >= 0 or _slot_directions[4] >= 0 or _slot_directions[7] >= 0
	for i: int in 9:
		var button := _slots[i]
		var used := _slot_directions[i] >= 0
		# Empty slots stay in the grid (to keep positions) but are invisible and inert.
		button.modulate.a = 1.0 if used else 0.0
		button.mouse_filter = Control.MOUSE_FILTER_STOP if used else Control.MOUSE_FILTER_IGNORE
		if not used:
			button.disabled = true
		button.custom_minimum_size = Vector2(
			CELL_SIZE.x if middle_column_used or i % 3 != 1 else COLLAPSED_SIZE.x,
			CELL_SIZE.y if middle_row_used or i / 3 != 1 else COLLAPSED_SIZE.y)
	visible = true


## Single-button mode: one action instead of directions.
func show_action(title: String, hint: String, button_text: String, enabled: bool) -> void:
	show_actions(title, hint, [{"label": button_text, "enabled": enabled}])


## Action mode with up to MAX_ACTIONS buttons; `options` holds {label: String, enabled: bool}.
func show_actions(title: String, hint: String, options: Array) -> void:
	_title.text = title
	_hint.text = hint
	_buttons.clear()
	_grid.visible = false
	_action_row.visible = true
	for i: int in MAX_ACTIONS:
		var button := _action_buttons[i]
		button.visible = i < options.size()
		if button.visible:
			button.text = options[i]["label"]
			button.disabled = not options[i]["enabled"]
	visible = true


func action_button(index: int = 0) -> Button:
	return _action_buttons[index]


func hide_target() -> void:
	visible = false


func has_option(direction: Grid.Direction) -> bool:
	return _buttons.has(direction)


## The arrow button for `direction`, or null (for tests driving the real button signals).
func option_button(direction: Grid.Direction) -> ArrowButton:
	return _buttons.get(direction)


func is_option_enabled(direction: Grid.Direction) -> bool:
	return _buttons.has(direction) and not _buttons[direction].disabled


func title_text() -> String:
	return _title.text


## 3x3 slot (row-major) whose position matches the vector's on-screen direction.
static func slot_index(vector: Vector2) -> int:
	var column := 1 if absf(vector.x) < 0.38 else (2 if vector.x > 0.0 else 0)
	var row := 1 if absf(vector.y) < 0.38 else (2 if vector.y > 0.0 else 0)
	return row * 3 + column


func _on_slot_down(slot: int) -> void:
	if _slot_directions[slot] >= 0:
		direction_preview_started.emit(_slot_directions[slot] as Grid.Direction)


func _on_slot_up(slot: int) -> void:
	if _slot_directions[slot] >= 0:
		direction_preview_ended.emit()


func _on_slot_pressed(slot: int) -> void:
	if _slot_directions[slot] >= 0:
		direction_chosen.emit(_slot_directions[slot] as Grid.Direction)
