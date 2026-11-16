class_name Backdrop
extends Control
## A painted sky for one world: gradient, nebula haze, stars, a distant planet and far-off floating
## islands, with a vignette. Painted once into an off-screen texture (repainted only on resize or
## theme change), so it costs one draw call per frame. No image assets.
## Used behind the 3D board (via the environment's canvas background) and behind every menu.

var theme_data: WorldTheme = WorldTheme.for_world(""):
	set(value):
		theme_data = value
		if _painter != null:
			_painter.theme_data = value
			_repaint()

var _viewport: SubViewport
var _painter: Painter
var _view: TextureRect


func _init(world_theme: WorldTheme = null) -> void:
	if world_theme != null:
		theme_data = world_theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_painter = Painter.new()
	_painter.theme_data = theme_data
	_viewport.add_child(_painter)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	resized.connect(_repaint)
	_repaint()


func _repaint() -> void:
	if _viewport == null or size.x < 1.0 or size.y < 1.0:
		return
	_viewport.size = Vector2i(size)
	_painter.size = size
	_painter.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Draws the sky into the off-screen viewport.
class Painter:
	extends Control

	static var _soft: GradientTexture2D
	static var _vignette: GradientTexture2D

	var theme_data: WorldTheme
	var _sky: GradientTexture2D
	var _sky_theme: WorldTheme

	func _draw() -> void:
		var t := theme_data
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		# Sky: top → horizon (about 62% down) → deep base, as one smooth gradient texture.
		draw_texture_rect(_sky_texture(t), Rect2(Vector2.ZERO, size), false)
		var soft := _soft_texture()
		# Nebula haze and horizon glow.
		_blob(soft, Vector2(w * 0.22, h * 0.24), Vector2(w * 1.1, h * 0.32), Color(t.nebula, 0.32))
		_blob(soft, Vector2(w * 0.85, h * 0.4), Vector2(w * 0.9, h * 0.28), Color(t.nebula.lightened(0.1), 0.22))
		_blob(soft, Vector2(w * 0.5, h * 0.62), Vector2(w * 1.8, h * 0.2), Color(t.horizon, 0.45))
		_blob(soft, Vector2(w * 0.5, h * 0.62), Vector2(w * 0.9, h * 0.07), Color(t.horizon.lightened(0.3), 0.35))
		# Stars, denser near the top.
		for i: int in 140:
			var x := MeshKit.hash01(i, 1, 91) * w
			var y := pow(MeshKit.hash01(i, 2, 91), 1.7) * h * 0.7
			var r := 0.8 + MeshKit.hash01(i, 3, 91) * 2.0
			var a := 0.25 + MeshKit.hash01(i, 4, 91) * 0.65
			draw_circle(Vector2(x, y), r, Color(0.85, 0.92, 1.0, a))
			if r > 2.4:
				draw_circle(Vector2(x, y), r * 3.0, Color(0.7, 0.85, 1.0, 0.06))
		# A distant planet with a lit rim.
		var planet := Vector2(w * 0.82, h * 0.1)
		var radius := w * 0.16
		_blob(soft, planet, Vector2.ONE * radius * 3.4, Color(t.horizon, 0.18))
		draw_circle(planet, radius, t.sky_top.lerp(t.nebula, 0.35))
		draw_arc(planet, radius - 2.0, deg_to_rad(110), deg_to_rad(260), 48, Color(t.accent, 0.5), 3.0, true)
		draw_circle(planet + Vector2(radius * 0.18, -radius * 0.12), radius * 0.92, t.sky_top.lerp(t.nebula, 0.2))
		# Far-off floating islands: two layers, the nearer one darker and larger.
		for layer: int in 2:
			var count := 4 if layer == 0 else 3
			for i: int in count:
				var cx := (i + 0.5 + (MeshKit.hash01(i, layer, 17) - 0.5) * 0.6) / count * w
				var cy := h * (0.58 + layer * 0.1 + MeshKit.hash01(i, layer, 19) * 0.08)
				var half := w * (0.05 + layer * 0.05) * (0.7 + MeshKit.hash01(i, layer, 23) * 0.6)
				var tone := Color(t.sky_bottom.lerp(t.sky_top, 0.3 + layer * 0.25), 0.75)
				_island(Vector2(cx, cy), half * 0.8, tone, Color(t.horizon, 0.5 - layer * 0.2), i * 7 + layer)
		# Vignette.
		draw_texture_rect(_vignette_texture(), Rect2(Vector2.ZERO, size), false, Color(0, 0, 0, 0.75))


	func _blob(texture: Texture2D, centre: Vector2, extent: Vector2, color: Color) -> void:
		draw_texture_rect(texture, Rect2(centre - extent * 0.5, extent), false, color)


	## A rock silhouette with a flat top, a lit rim and a jagged taper below; sometimes a ruin on top.
	func _island(centre: Vector2, half: float, color: Color, rim: Color, seed: int) -> void:
		var outline := PackedVector2Array([centre + Vector2(-half, 0)])
		var steps := 7
		for i: int in range(1, steps):
			var f := float(i) / steps
			var depth := sin(f * PI) * half * (1.1 + MeshKit.hash01(seed, i, 29) * 0.9)
			outline.append(centre + Vector2(lerpf(-half, half, f), depth))
		outline.append(centre + Vector2(half, 0))
		var top_right := centre + Vector2(half * 0.9, -half * 0.08)
		var top_left := centre + Vector2(-half * 0.9, -half * 0.08)
		outline.append(top_right)
		outline.append(top_left)
		draw_colored_polygon(outline, color)
		draw_line(top_left, top_right, rim, maxf(2.0, half * 0.04), true)
		if MeshKit.hash01(seed, 5, 31) > 0.45:
			var pillar_w := half * 0.12
			var pillar_h := half * (0.4 + MeshKit.hash01(seed, 6, 31) * 0.5)
			var base := centre + Vector2((MeshKit.hash01(seed, 7, 31) - 0.5) * half, -half * 0.08)
			draw_rect(Rect2(base - Vector2(pillar_w, pillar_h), Vector2(pillar_w, pillar_h)), color)
			draw_rect(Rect2(base - Vector2(pillar_w - pillar_w * 2.6, pillar_h * 0.7), Vector2(pillar_w, pillar_h * 0.7)), color)
			draw_rect(Rect2(base - Vector2(pillar_w * 1.2, pillar_h + pillar_w * 0.6), Vector2(pillar_w * 3.4, pillar_w * 0.6)),
				color)


	func _sky_texture(t: WorldTheme) -> GradientTexture2D:
		if _sky == null or _sky_theme != t:
			var gradient := Gradient.new()
			gradient.set_color(0, t.sky_top)
			gradient.set_color(1, t.sky_top.darkened(0.25))
			gradient.add_point(0.3, t.sky_top.lerp(t.sky_bottom, 0.45))
			gradient.add_point(0.62, t.sky_bottom)
			_sky = GradientTexture2D.new()
			_sky.gradient = gradient
			_sky.fill_from = Vector2(0, 0)
			_sky.fill_to = Vector2(0, 1)
			_sky.width = 4
			_sky.height = 512
			_sky_theme = t
		return _sky


	static func _soft_texture() -> GradientTexture2D:
		if _soft == null:
			var gradient := Gradient.new()
			gradient.set_color(0, Color(1, 1, 1, 1))
			gradient.set_color(1, Color(1, 1, 1, 0))
			gradient.add_point(0.5, Color(1, 1, 1, 0.3))
			_soft = GradientTexture2D.new()
			_soft.gradient = gradient
			_soft.fill = GradientTexture2D.FILL_RADIAL
			_soft.fill_from = Vector2(0.5, 0.5)
			_soft.fill_to = Vector2(1.0, 0.5)
			_soft.width = 128
			_soft.height = 128
		return _soft


	static func _vignette_texture() -> GradientTexture2D:
		if _vignette == null:
			var gradient := Gradient.new()
			gradient.set_color(0, Color(0, 0, 0, 0))
			gradient.set_color(1, Color(0, 0, 0, 1))
			gradient.add_point(0.6, Color(0, 0, 0, 0.15))
			_vignette = GradientTexture2D.new()
			_vignette.gradient = gradient
			_vignette.fill = GradientTexture2D.FILL_RADIAL
			_vignette.fill_from = Vector2(0.5, 0.5)
			_vignette.fill_to = Vector2(1.15, 0.5)
			_vignette.width = 128
			_vignette.height = 128
		return _vignette
