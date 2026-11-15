class_name LevelSelectScreen
extends Control
## Placeholder level list grouped by world, in catalog order. Emits intent only.
## Locked levels (P-013) are shown but disabled; completed ones show best actions and stars.

signal level_chosen(level_id: String)
signal back_requested

const MARGIN := 48

var _catalog: LevelCatalog
var _progress: ProgressStore
var _level_buttons: Dictionary[String, Button] = {}
var _margin := MarginContainer.new()


func setup(catalog: LevelCatalog, progress: ProgressStore) -> void:
	_catalog = catalog
	_progress = progress


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
			var button := _level_row(entry)
			var level_id := entry.level_id
			button.pressed.connect(func() -> void: level_chosen.emit(level_id))
			list.add_child(button)
			_level_buttons[level_id] = button


## A row: "N.  Title" on the left; "Best N" and stars, or "Locked", on the right.
func _level_row(entry: LevelCatalog.Entry) -> Button:
	var unlocked := Progression.is_unlocked(_catalog, _progress, entry.level_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 110)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var title := Label.new()
	title.name = "Title"
	title.text = "%d.  %s" % [entry.order + 1, entry.title]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	UiTheme.style_label(title, 32, Palette.TEXT if unlocked else Palette.TEXT_MUTED.darkened(0.3))
	row.add_child(title)
	var detail := Label.new()
	detail.name = "Detail"
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_label(detail, 26, Palette.TEXT_MUTED)
	row.add_child(detail)
	var best := _progress.best_actions(entry.level_id)
	if not unlocked:
		detail.text = "Locked"
	elif best >= 0:
		detail.text = "Best %d" % best
		var stars := StarRating.new()
		stars.name = "Stars"
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stars.earned = Progression.stars(best, entry.target_actions, entry.optimal_actions)
		row.add_child(stars)
	var end_spacer := spacer.duplicate() as Control
	row.add_child(end_spacer)
	return button


## The row's visible texts, e.g. ["2.  Title", "Best 4"] (for tests).
func row_texts(level_id: String) -> PackedStringArray:
	var button := level_button(level_id)
	var row := button.get_child(0)
	return PackedStringArray([(row.get_node("Title") as Label).text, (row.get_node("Detail") as Label).text])


func row_stars(level_id: String) -> int:
	var stars := level_button(level_id).get_child(0).get_node_or_null("Stars") as StarRating
	return stars.earned if stars != null else 0


func _apply_safe_area() -> void:
	UiTheme.apply_safe_margins(_margin, MARGIN)


## Level ids in display order (for tests).
func listed_level_ids() -> PackedStringArray:
	return PackedStringArray(_level_buttons.keys())


func level_button(level_id: String) -> Button:
	return _level_buttons.get(level_id)
