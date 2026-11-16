class_name UiTheme
extends RefCounted
## Shared UI design system (docs/06 §4): translucent "glass" panels with thin metallic borders,
## glowing primary actions and a display face for titles. Used by every screen.

## Panel glass: navy, mostly opaque so text stays readable over the 3D scene.
const GLASS := Color(0.05, 0.09, 0.17, 0.82)
const GLASS_LIGHT := Color(0.09, 0.15, 0.26, 0.88)
const METAL_BORDER := Color(0.55, 0.66, 0.8, 0.35)

static var _display_font: FontVariation


## How far a button's face sits above its base, and how far it sinks when pressed.
const DEPTH := 8
const SOLID := Color(0.1, 0.17, 0.3)
const SOLID_EDGE := Color(0.04, 0.08, 0.16)
const PLAY_GREEN := Color("#2FBF71")
const PLAY_CYAN := Color("#1FB6D1")


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 34
	theme.set_stylebox("normal", "Button", raised(SOLID, SOLID_EDGE, METAL_BORDER))
	theme.set_stylebox("hover", "Button", raised(SOLID.lightened(0.06), SOLID_EDGE, Color(Palette.CYAN_ENERGY, 0.7)))
	theme.set_stylebox("pressed", "Button", sunk(SOLID.lightened(0.1), SOLID_EDGE, Palette.CYAN_ENERGY))
	theme.set_stylebox("disabled", "Button", raised(Color(0.07, 0.1, 0.17, 0.75), Color(0.03, 0.05, 0.1, 0.75),
		Color(METAL_BORDER, 0.12)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.TEXT)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(Palette.TEXT_MUTED, 0.45))
	theme.set_constant("h_separation", "Button", 14)
	return theme


static func box(background: Color, border: Color, radius: int = 24) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(20)
	style.anti_aliasing = true
	return style


## A chunky button face standing on a darker base (the base shows as a thick bottom edge).
static func raised(face: Color, edge: Color, rim: Color, radius: int = 26) -> StyleBoxFlat:
	var style := box(face, edge, radius)
	style.set_border_width_all(0)
	style.border_width_bottom = DEPTH
	style.shadow_color = Color(rim, rim.a * 0.6)
	style.shadow_size = 3
	style.content_margin_bottom = 20 + DEPTH
	return style


## The same button pushed down: the base nearly hidden and the face shifted to meet it.
static func sunk(face: Color, edge: Color, rim: Color, radius: int = 26) -> StyleBoxFlat:
	var style := raised(face, edge, rim, radius)
	style.border_width_bottom = 2
	style.expand_margin_top = -float(DEPTH - 2)
	style.content_margin_top = 20 + DEPTH - 2
	style.content_margin_bottom = 22
	return style


## Gives `button` a quick squash when pressed and a spring back on release (menus and HUD).
static func add_press_bounce(button: BaseButton) -> void:
	var press := func() -> void:
		button.pivot_offset = button.size * 0.5
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	var release := func() -> void:
		button.pivot_offset = button.size * 0.5
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button.button_down.connect(press)
	button.button_up.connect(release)


## A floating glass panel with a soft shadow and an accent-tinted border.
static func panel(accent: Color = Palette.CYAN_ENERGY, radius: int = 28) -> StyleBoxFlat:
	var style := box(GLASS, Color(accent, 0.45), radius)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	style.set_content_margin_all(24)
	return style


## The vivid look for a screen's primary action: a bright face on a deep base, white bold text.
static func make_primary(button: Button, accent: Color = PLAY_GREEN) -> void:
	var edge := accent.darkened(0.45)
	var normal := raised(accent, edge, accent)
	normal.shadow_color = Color(accent, 0.45)
	normal.shadow_size = 12
	var hover := raised(accent.lightened(0.08), edge, accent)
	hover.shadow_color = Color(accent, 0.55)
	hover.shadow_size = 14
	var pressed := sunk(accent.lightened(0.12), edge, accent)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_override("font", display_font())
	button.add_theme_color_override("font_outline_color", Color(edge, 0.9))
	button.add_theme_constant_override("outline_size", 8)


## A bolder, wider-spaced variant of the UI font for titles only (docs/06 §7).
static func display_font() -> FontVariation:
	if _display_font == null:
		_display_font = FontVariation.new()
		_display_font.base_font = ThemeDB.fallback_font
		_display_font.variation_embolden = 0.9
		_display_font.spacing_glyph = 3
	return _display_font


static func style_title(label: Label, font_size: int, color: Color) -> void:
	style_label(label, font_size, color)
	label.add_theme_font_override("font", display_font())
	label.add_theme_color_override("font_shadow_color", Color(color, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 14)


## Applies `base` margins plus the device's safe-area insets (notches, system bars) to `margin`.
## Mobile only: on desktop the display safe area describes the screen, not the window.
static func apply_safe_margins(margin: MarginContainer, base: int) -> void:
	var insets := [0.0, 0.0, 0.0, 0.0]  # left, top, right, bottom in viewport pixels
	if OS.has_feature("mobile") and margin.is_inside_tree():
		var screen := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		var scale := margin.get_viewport().get_visible_rect().size.x / maxf(screen.x, 1.0)
		insets = [safe.position.x * scale, safe.position.y * scale,
			(screen.x - safe.end.x) * scale, (screen.y - safe.end.y) * scale]
	var sides := ["left", "top", "right", "bottom"]
	for i: int in 4:
		margin.add_theme_constant_override("margin_" + sides[i], base + int(insets[i]))


static func style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
