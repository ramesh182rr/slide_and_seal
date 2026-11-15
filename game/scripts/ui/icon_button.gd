class_name IconButton
extends Button
## A button that draws its own icon (the built-in font has no rotate/zoom glyphs).

enum Icon { ROTATE_LEFT, ROTATE_RIGHT, ZOOM_IN, ZOOM_OUT, RESET_VIEW }

var icon_kind: Icon = Icon.RESET_VIEW:
	set(value):
		icon_kind = value
		queue_redraw()


func _init(p_icon: Icon = Icon.RESET_VIEW) -> void:
	icon_kind = p_icon
	custom_minimum_size = Vector2(96, 96)
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := get_theme_stylebox(state)
		if box != null:
			var copy := box.duplicate() as StyleBox
			copy.set_content_margin_all(0)
			add_theme_stylebox_override(state, copy)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.26
	var color := get_theme_color("font_disabled_color" if disabled else "font_color")
	var width := maxf(3.0, r * 0.22)
	match icon_kind:
		Icon.ROTATE_LEFT, Icon.ROTATE_RIGHT:
			var clockwise := icon_kind == Icon.ROTATE_RIGHT
			# An open arc with an arrowhead at its end.
			var start := deg_to_rad(-60.0 if clockwise else 240.0)
			var sweep := deg_to_rad(270.0) * (1.0 if clockwise else -1.0)
			draw_arc(c, r, start, start + sweep, 24, color, width, true)
			var end_angle := start + sweep
			var tip := c + Vector2.from_angle(end_angle) * r
			var tangent := Vector2.from_angle(end_angle + (PI / 2.0 if clockwise else -PI / 2.0))
			var normal := Vector2.from_angle(end_angle)
			draw_colored_polygon(PackedVector2Array([
				# A narrow head (about 35°) so its direction reads at a glance.
				tip + tangent * r * 0.95,
				tip + normal * r * 0.34,
				tip - normal * r * 0.34,
			]), color)
		Icon.ZOOM_IN, Icon.ZOOM_OUT:
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), color, width * 1.2)
			if icon_kind == Icon.ZOOM_IN:
				draw_line(c - Vector2(0, r), c + Vector2(0, r), color, width * 1.2)
		Icon.RESET_VIEW:
			# Four corner brackets: "fit the board".
			var k := r * 0.45
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var corner := c + Vector2(r * sx, r * sy)
					draw_line(corner, corner - Vector2(k * sx, 0), color, width)
					draw_line(corner, corner - Vector2(0, k * sy), color, width)
