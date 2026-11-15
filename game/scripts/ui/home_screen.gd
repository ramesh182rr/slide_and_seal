class_name HomeScreen
extends Control
## Placeholder home screen (D-011): title, tagline and Play. Emits intent only.

signal play_requested
signal settings_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make_theme()
	var background := ColorRect.new()
	background.color = Palette.DEEP_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(760, 0)
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)

	var title := Label.new()
	title.text = "Slide & Seal"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_label(title, 96, Palette.CYAN_ENERGY)
	column.add_child(title)
	var tagline := Label.new()
	tagline.text = "Reconfigure reality. Control the maze. Complete the seal."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_label(tagline, 32, Palette.TEXT_MUTED)
	column.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 80)
	column.add_child(spacer)
	var play := Button.new()
	play.name = "Play"
	play.text = "Play"
	play.custom_minimum_size = Vector2(0, 130)
	play.focus_mode = Control.FOCUS_NONE
	UiTheme.make_primary(play)
	play.pressed.connect(func() -> void: play_requested.emit())
	column.add_child(play)
	var settings := Button.new()
	settings.name = "Settings"
	settings.text = "Settings"
	settings.custom_minimum_size = Vector2(0, 110)
	settings.focus_mode = Control.FOCUS_NONE
	settings.pressed.connect(func() -> void: settings_requested.emit())
	column.add_child(settings)
