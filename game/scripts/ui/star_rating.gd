class_name StarRating
extends Control
## Draws 0–3 earned stars out of 3 (no dependency on a font's star glyph).
## Each star is drawn as convex pieces (pentagon + five tips) so triangulation is never an issue.

const MAX_STARS := 3

var earned: int = 0:
	set(value):
		earned = clampi(value, 0, MAX_STARS)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(150, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.y * 0.48, size.x / (MAX_STARS * 2.2))
	var gap := size.x / MAX_STARS
	for i: int in MAX_STARS:
		var center := Vector2(gap * (i + 0.5), size.y * 0.5)
		draw_star(self, center, radius, Palette.MECHANISM_AMBER if i < earned else Color(Palette.BOARD_SLATE, 0.8))


static func draw_star(item: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i: int in 5:
		var angle := -PI / 2.0 + i * TAU / 5.0
		outer.append(center + Vector2.from_angle(angle) * radius)
		inner.append(center + Vector2.from_angle(angle + TAU / 10.0) * radius * 0.42)
	item.draw_colored_polygon(inner, color)
	for i: int in 5:
		item.draw_colored_polygon(PackedVector2Array([outer[i], inner[i], inner[(i + 4) % 5]]), color)
