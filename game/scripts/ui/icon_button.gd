class_name IconButton
extends Button
## A button that draws its own vector icon (the built-in font has no such glyphs). With text, the
## icon sits to the left of the label; without text, it is centred.

enum Icon { ROTATE_LEFT, ROTATE_RIGHT, ZOOM_IN, ZOOM_OUT, RESET_VIEW, BACK, UNDO, RESTART, PLAY, SETTINGS, LOCK,
	GRID, NONE }

const ICON_TEXT_GAP := 16.0

var icon_kind: Icon = Icon.RESET_VIEW:
	set(value):
		icon_kind = value
		_update_padding()
		queue_redraw()


func _init(p_icon: Icon = Icon.RESET_VIEW, p_text: String = "") -> void:
	icon_kind = p_icon
	text = p_text
	custom_minimum_size = Vector2(96, 96)
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	_update_padding()


## Text buttons get room on the left for the icon.
func _update_padding() -> void:
	if not is_inside_tree():
		return
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := get_theme_stylebox(state)
		if box == null:
			continue
		var copy := box.duplicate() as StyleBox
		if text == "":
			copy.set_content_margin_all(0)
		else:
			copy.content_margin_left = 84.0 + ICON_TEXT_GAP
		add_theme_stylebox_override(state, copy)


func _draw() -> void:
	if icon_kind == Icon.NONE:
		return
	var font_color := "font_disabled_color" if disabled else ("font_pressed_color" if button_pressed else "font_color")
	var color := get_theme_color(font_color)
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.26
	if text != "":
		r = minf(size.y, 96.0) * 0.22
		c = Vector2(22.0 + r * 1.1, size.y * 0.5)
	draw_icon(self, icon_kind, c, r, color)


## Draws `icon` centred on `c` with radius `r` on any CanvasItem (also used by non-button widgets).
static func draw_icon(item: CanvasItem, icon: Icon, c: Vector2, r: float, color: Color) -> void:
	var width := maxf(3.0, r * 0.22)
	match icon:
		Icon.ROTATE_LEFT, Icon.ROTATE_RIGHT:
			var clockwise := icon == Icon.ROTATE_RIGHT
			_arc_arrow(item, c, r, deg_to_rad(-60.0 if clockwise else 240.0), 270.0 * (1.0 if clockwise else -1.0),
				color, width)
		Icon.UNDO:
			_arc_arrow(item, c, r, deg_to_rad(20.0), -250.0, color, width)
		Icon.RESTART:
			_arc_arrow(item, c, r, deg_to_rad(-100.0), 300.0, color, width)
		Icon.ZOOM_IN, Icon.ZOOM_OUT:
			item.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), color, width * 1.2)
			if icon == Icon.ZOOM_IN:
				item.draw_line(c - Vector2(0, r), c + Vector2(0, r), color, width * 1.2)
		Icon.RESET_VIEW:
			# Four corner brackets: "fit the board".
			var k := r * 0.45
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var corner := c + Vector2(r * sx, r * sy)
					item.draw_line(corner, corner - Vector2(k * sx, 0), color, width)
					item.draw_line(corner, corner - Vector2(0, k * sy), color, width)
		Icon.BACK:
			item.draw_line(c + Vector2(r, 0), c - Vector2(r * 0.9, 0), color, width * 1.1, true)
			item.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.75), c - Vector2(r, 0),
				c + Vector2(-r * 0.2, r * 0.75)]), color, width * 1.1, true)
		Icon.PLAY:
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r, 0),
				c + Vector2(-r * 0.6, r)]), color)
		Icon.SETTINGS:
			var teeth := PackedVector2Array()
			for i: int in 16:
				var angle := TAU * i / 16.0
				teeth.append(c + Vector2.from_angle(angle) * (r if i % 2 == 0 else r * 0.74))
			teeth.append(teeth[0])
			item.draw_polyline(teeth, color, width * 0.8, true)
			item.draw_arc(c, r * 0.32, 0.0, TAU, 20, color, width * 0.8, true)
		Icon.LOCK:
			item.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.1), Vector2(r * 1.5, r * 1.1)), color)
			item.draw_arc(c + Vector2(0, -r * 0.15), r * 0.5, PI, TAU, 16, color, width, true)
			item.draw_line(c + Vector2(-r * 0.5, -r * 0.15), c + Vector2(-r * 0.5, -r * 0.05), color, width)
			item.draw_line(c + Vector2(r * 0.5, -r * 0.15), c + Vector2(r * 0.5, -r * 0.05), color, width)
		Icon.GRID:
			var s := r * 0.8
			for gx: float in [-1.0, 1.0]:
				for gy: float in [-1.0, 1.0]:
					item.draw_rect(Rect2(c + Vector2(gx * s * 0.6 - s * 0.45, gy * s * 0.6 - s * 0.45), Vector2(s * 0.9, s * 0.9)),
						color)


## An open arc with a narrow arrowhead at its end (`sweep_degrees` < 0 runs anticlockwise).
static func _arc_arrow(item: CanvasItem, c: Vector2, r: float, start: float, sweep_degrees: float, color: Color,
		width: float) -> void:
	var sweep := deg_to_rad(sweep_degrees)
	var clockwise := sweep > 0.0
	item.draw_arc(c, r, start, start + sweep, 24, color, width, true)
	var end_angle := start + sweep
	var tip := c + Vector2.from_angle(end_angle) * r
	var tangent := Vector2.from_angle(end_angle + (PI / 2.0 if clockwise else -PI / 2.0))
	var normal := Vector2.from_angle(end_angle)
	item.draw_colored_polygon(PackedVector2Array([
		# A narrow head (about 35°) so its direction reads at a glance.
		tip + tangent * r * 0.95,
		tip + normal * r * 0.34,
		tip - normal * r * 0.34,
	]), color)
