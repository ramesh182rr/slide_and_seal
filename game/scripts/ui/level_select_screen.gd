class_name LevelSelectScreen
extends Control
## Placeholder level list grouped by world, in catalog order. Emits intent only.
## Every level is open until save data and unlocking exist.

signal level_chosen(level_id: String)
signal back_requested

const MARGIN := 48

var _catalog: LevelCatalog
var _level_buttons: Dictionary[String, Button] = {}
var _margin := MarginContainer.new()


func setup(catalog: LevelCatalog) -> void:
	_catalog = catalog


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
	# An instance method, so the connection ends automatically when this screen is freed.
	get_viewport().size_changed.connect(_apply_safe_area)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	_margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)
	var title := Label.new()
	title.text = "Levels"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_label(title, 52, Palette.TEXT)
	header.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	for world: LevelCatalog.World in _catalog.worlds:
		var world_label := Label.new()
		world_label.text = world.title
		UiTheme.style_label(world_label, 36, Palette.MECHANISM_AMBER)
		list.add_child(world_label)
		for entry: LevelCatalog.Entry in world.entries:
			var button := Button.new()
			button.text = "%d.  %s" % [entry.order + 1, entry.title]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0, 110)
			button.focus_mode = Control.FOCUS_NONE
			var level_id := entry.level_id
			button.pressed.connect(func() -> void: level_chosen.emit(level_id))
			list.add_child(button)
			_level_buttons[level_id] = button


func _apply_safe_area() -> void:
	UiTheme.apply_safe_margins(_margin, MARGIN)


## Level ids in display order (for tests).
func listed_level_ids() -> PackedStringArray:
	return PackedStringArray(_level_buttons.keys())


func level_button(level_id: String) -> Button:
	return _level_buttons.get(level_id)
