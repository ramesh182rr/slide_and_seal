class_name BrandMark
extends RefCounted
## The Slide & Seal emblem: a glowing hexagon around an isometric cube (the energy core's chamber).
## One drawing shared by the app icon generator, the boot splash, the startup reveal and Home.

const RING := Color("#38D6E8")
const PALE := Color("#DDF6FF")
## Boot splash / reveal background; equals application/boot_splash/bg_color.
const SPLASH_BG := Color("#050B16")


## Draws the emblem centred on `c` with hexagon radius `r`. `glow` adds the soft halo and fills.
static func draw_emblem(item: CanvasItem, c: Vector2, r: float, ring: Color = RING, cube: Color = PALE,
		glow: bool = true) -> void:
	var hexagon := _hexagon(c, r)
	if glow:
		for w: float in [r * 0.34, r * 0.22, r * 0.14]:
			item.draw_polyline(hexagon, Color(ring, 0.1 * ring.a), w, true)
	item.draw_polyline(hexagon, ring, r * 0.07, true)
	var inner := _hexagon(c, r * 0.56)
	if glow:
		item.draw_colored_polygon(inner.slice(0, 6), Color(ring, 0.22 * ring.a))
		item.draw_colored_polygon(PackedVector2Array([inner[0], inner[1], c, inner[5]]), Color(cube, 0.28 * cube.a))
	item.draw_polyline(inner, cube, r * 0.05, true)
	for i: int in [1, 3, 5]:
		item.draw_line(c, inner[i], cube, r * 0.05, true)
	item.draw_circle(c, r * 0.08, cube)


## The wordmark font: the UI font, emboldened and spaced.
static func wordmark_font() -> FontVariation:
	return UiTheme.display_font()


## Layout shared by the boot splash image and the reveal, for a square of side `s` centred on `c`:
## [emblem centre, emblem radius, wordmark baseline-left, wordmark font size].
static func splash_layout(c: Vector2, s: float) -> Array:
	var font_size := int(s * 0.085)
	var width := wordmark_font().get_string_size("SLIDE & SEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return [c - Vector2(0, s * 0.1), s * 0.17, Vector2(c.x - width * 0.5, c.y + s * 0.2), font_size]


static func draw_wordmark(item: CanvasItem, at: Vector2, font_size: int, alpha: float = 1.0) -> void:
	var font := wordmark_font()
	for outline: int in [10, 6]:
		item.draw_string_outline(font, at, "SLIDE & SEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline,
			Color(RING, 0.12 * alpha))
	item.draw_string(font, at, "SLIDE & SEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(PALE, alpha))


static func _hexagon(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in 7:
		points.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0) * r)
	return points
