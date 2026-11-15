class_name ArrowButton
extends Button
## A button that draws a direction arrow itself (no dependency on font arrow glyphs).
## `screen_angle` is in radians, 0 = pointing right, increasing clockwise (screen y down).

var screen_angle: float = 0.0:
	set(value):
		screen_angle = value
		queue_redraw()


## The arrow is drawn directly, so the theme's text padding only inflates the minimum size
## (which matters for collapsed, empty slots). Keep the look, drop the padding.
func _ready() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := get_theme_stylebox(state)
		if box != null:
			var copy := box.duplicate() as StyleBox
			copy.set_content_margin_all(0)
			add_theme_stylebox_override(state, copy)


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.3
	var color := get_theme_color("font_disabled_color" if disabled else "font_color")
	var head := PackedVector2Array([Vector2(r, 0), Vector2(0, -r * 0.75), Vector2(0, r * 0.75)])
	var shaft := PackedVector2Array([Vector2(0, -r * 0.28), Vector2(0, r * 0.28), Vector2(-r, r * 0.28), Vector2(-r, -r * 0.28)])
	draw_colored_polygon(_place(head, center), color)
	draw_colored_polygon(_place(shaft, center), color)


func _place(points: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for point: Vector2 in points:
		placed.append(center + point.rotated(screen_angle))
	return placed
