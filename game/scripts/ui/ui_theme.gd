class_name UiTheme
extends RefCounted
## Shared placeholder UI styling (D-011) built from the doc 06 palette. Used by every screen.


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 34
	theme.set_stylebox("normal", "Button", box(Palette.NAVY_SURFACE, Palette.CYAN_ENERGY.darkened(0.35)))
	theme.set_stylebox("hover", "Button", box(Palette.NAVY_SURFACE.lightened(0.08), Palette.CYAN_ENERGY))
	theme.set_stylebox("pressed", "Button", box(Palette.BOARD_SLATE, Palette.CYAN_ENERGY))
	theme.set_stylebox("disabled", "Button", box(Palette.DEEP_BACKGROUND, Palette.BOARD_SLATE))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.TEXT)
	theme.set_color("font_pressed_color", "Button", Palette.TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_MUTED.darkened(0.3))
	return theme


static func box(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(20)
	return style


## The accent (mint-bordered) look for a screen's primary action.
static func make_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(Palette.NAVY_SURFACE, Palette.MINT_SUCCESS))
	button.add_theme_stylebox_override("hover", box(Palette.NAVY_SURFACE.lightened(0.08), Palette.MINT_SUCCESS))


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
