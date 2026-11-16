class_name StarRating
extends Control
## Draws 0–3 earned stars out of 3 (no dependency on a font's star glyph).
## Each star is drawn as convex pieces (pentagon + five tips) so triangulation is never an issue.

const MAX_STARS := 3

var earned: int = 0:
	set(value):
		earned = clampi(value, 0, MAX_STARS)
		queue_redraw()


## Stars lit so far while revealing (>= MAX_STARS when not animating).
var _revealed := float(MAX_STARS)


## Lights the earned stars one after another, each with a small pop.
func reveal() -> void:
	_revealed = 0.0
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_method(func(value: float) -> void:
		_revealed = value
		queue_redraw(), 0.0, float(earned), 0.3 * maxi(earned, 1))
	tween.tween_callback(func() -> void: _revealed = float(MAX_STARS))


func _init() -> void:
	custom_minimum_size = Vector2(150, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.y * 0.48, size.x / (MAX_STARS * 2.2))
	var gap := size.x / MAX_STARS
	for i: int in MAX_STARS:
		var center := Vector2(gap * (i + 0.5), size.y * 0.5)
		var lit := i < earned and float(i) < _revealed
		# The star being revealed overshoots, then settles.
		var grow := clampf(_revealed - float(i), 0.0, 1.0)
		var pop := 1.0 + 0.45 * sin(grow * PI) if lit and grow < 1.0 else 1.0
		draw_star(self, center, radius * pop, Palette.MECHANISM_AMBER if lit else Color(Palette.BOARD_SLATE, 0.8))


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
