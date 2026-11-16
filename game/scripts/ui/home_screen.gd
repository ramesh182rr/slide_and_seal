class_name HomeScreen
extends Control
## Home (docs/06 §5): the world's sky, a live diorama, the emblem and wordmark, then Continue,
## Campaign and Settings. Emits intent only.

## Campaign: open world/level selection.
signal play_requested
## Jump straight into the next level to play.
signal continue_requested
signal settings_requested

const DIORAMA_LEVEL := "res://data/levels/world_01_level_006.json"

var _continue_label := "Continue"
var _diorama: DioramaView
var _margin := MarginContainer.new()


## `continue_label` names the level Continue opens, e.g. "Continue · 3. Lever and Gate".
func setup(continue_label: String) -> void:
	_continue_label = continue_label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make_theme()
	var world := WorldTheme.for_world("world_01_awakening")
	add_child(Backdrop.new(world))

	_diorama = DioramaView.new()
	_diorama.framing = 1.7
	_diorama.anchor_right = 1.0
	_diorama.anchor_bottom = 0.56
	_diorama.offset_top = 120
	add_child(_diorama)
	_diorama.show_level(DIORAMA_LEVEL)

	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	UiTheme.apply_safe_margins(_margin, 56)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	column.alignment = BoxContainer.ALIGNMENT_END
	_margin.add_child(column)

	var emblem := Emblem.new()
	emblem.custom_minimum_size = Vector2(0, 150)
	column.add_child(emblem)
	var title := Label.new()
	title.text = "SLIDE & SEAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_title(title, 92, Color("#DDF6FF"))
	title.add_theme_color_override("font_shadow_color", Color(Palette.CYAN_ENERGY, 0.55))
	column.add_child(title)
	var tagline := Label.new()
	tagline.text = "Reconfigure reality. Control the maze. Complete the seal."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_label(tagline, 30, Color(Palette.TEXT, 0.75))
	column.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	column.add_child(spacer)
	var resume := IconButton.new(IconButton.Icon.PLAY, _continue_label)
	resume.name = "Continue"
	resume.custom_minimum_size = Vector2(0, 132)
	resume.add_theme_font_size_override("font_size", 38)
	resume.clip_text = true
	UiTheme.make_primary(resume, Palette.CYAN_ENERGY)
	resume.pressed.connect(func() -> void: continue_requested.emit())
	column.add_child(resume)
	var play := IconButton.new(IconButton.Icon.GRID, "Campaign")
	play.name = "Play"
	play.custom_minimum_size = Vector2(0, 112)
	play.pressed.connect(func() -> void: play_requested.emit())
	column.add_child(play)
	var settings := IconButton.new(IconButton.Icon.SETTINGS, "Settings")
	settings.name = "Settings"
	settings.custom_minimum_size = Vector2(0, 112)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	column.add_child(settings)


func diorama() -> DioramaView:
	return _diorama


## The brand mark: a glowing hexagon around an isometric cube (the energy core's chamber).
class Emblem:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.y * 0.5, 80.0)
		var hexagon := PackedVector2Array()
		for i: int in 7:
			hexagon.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0) * r)
		draw_polyline(hexagon, Color(Palette.CYAN_ENERGY, 0.25), 14.0, true)
		draw_polyline(hexagon, Palette.CYAN_ENERGY, 4.0, true)
		var inner := PackedVector2Array()
		for i: int in 7:
			inner.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0) * r * 0.56)
		draw_colored_polygon(inner.slice(0, 6), Color(Palette.CYAN_ENERGY, 0.18))
		draw_polyline(inner, Color("#DDF6FF"), 3.0, true)
		for i: int in [1, 3, 5]:
			draw_line(c, inner[i], Color("#DDF6FF"), 3.0, true)
		draw_circle(c, r * 0.08, Color.WHITE)
