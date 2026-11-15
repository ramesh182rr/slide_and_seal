class_name CompletionCard
extends PanelContainer
## Shown in the HUD when the seal completes: actions against target, then Next / Level select.
## Buttons are created once (see MechanismPanel for why nothing is freed during a signal).

signal next_requested
signal levels_requested

var _summary := Label.new()
var _stars := StarRating.new()
var _best := Label.new()
var _next := Button.new()
var _levels := Button.new()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.NAVY_SURFACE, 0.96)
	style.border_color = Palette.MINT_SUCCESS
	style.set_border_width_all(3)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(26)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Seal complete"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_label(title, 44, Palette.MINT_SUCCESS)
	header.add_child(title)
	header.add_child(_stars)
	UiTheme.style_label(_summary, 30, Palette.TEXT_MUTED)
	column.add_child(_summary)
	UiTheme.style_label(_best, 28, Palette.MECHANISM_AMBER)
	column.add_child(_best)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	for entry: Array in [[_levels, "Level select", levels_requested], [_next, "Next level", next_requested]]:
		var button: Button = entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(0, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		var request: Signal = entry[2]
		button.pressed.connect(func() -> void: request.emit())
		buttons.add_child(button)
	UiTheme.make_primary(_next)


func show_result(actions: int, target: int, stars: int, new_best: bool, has_next: bool) -> void:
	_summary.text = "Actions %d  ·  Target %d%s" % [actions, target, "  ·  Target met" if actions <= target else ""]
	_stars.earned = stars
	_best.text = "New best!" if new_best else ""
	_best.visible = new_best
	_next.visible = has_next
	visible = true


func stars_shown() -> int:
	return _stars.earned


func is_new_best_shown() -> bool:
	return _best.visible


func summary_text() -> String:
	return _summary.text


func has_next_button() -> bool:
	return _next.visible


func next_button() -> Button:
	return _next


func levels_button() -> Button:
	return _levels
