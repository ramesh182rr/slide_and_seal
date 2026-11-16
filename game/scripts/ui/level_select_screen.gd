class_name LevelSelectScreen
extends Control
## Campaign screen (docs/06 §5–6): one world at a time on a card with its live 3D diorama, title,
## theme line and progress, then a grid of that world's levels. Arrows or a horizontal swipe on the
## card change world. Locked levels (P-013) are shown but disabled; completed ones show stars.
## Emits intent only.

signal level_chosen(level_id: String)
signal back_requested

const MARGIN := 40
const COLUMNS := 3
const SWIPE_DISTANCE := 90.0

var _catalog: LevelCatalog
var _progress: ProgressStore
var _level_buttons: Dictionary[String, Button] = {}
var _level_texts: Dictionary[String, PackedStringArray] = {}
var _level_stars: Dictionary[String, int] = {}
var _grids: Array[GridContainer] = []
var _pages: Array[Page] = []
var _world_index := 0
var _margin := MarginContainer.new()
var _backdrop: Backdrop
var _diorama: DioramaView
var _card := PanelContainer.new()
var _world_number := Label.new()
var _world_title := Label.new()
var _world_tagline := Label.new()
var _world_progress := Label.new()
var _previous := IconButton.new(IconButton.Icon.BACK)
var _next := IconButton.new(IconButton.Icon.BACK)
var _drag_start := Vector2.ZERO
var _dragging := false


## `diorama` is the app's shared live view (null: the screen makes its own).
func setup(catalog: LevelCatalog, progress: ProgressStore, diorama: DioramaView = null) -> void:
	_catalog = catalog
	_progress = progress
	_diorama = diorama


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make_theme()
	_backdrop = Backdrop.new()
	add_child(_backdrop)

	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_apply_safe_area()
	# An instance method, so the connection ends automatically when this screen is freed.
	get_viewport().size_changed.connect(_apply_safe_area)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	_margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	var back := IconButton.new(IconButton.Icon.BACK)
	back.name = "Back"
	back.custom_minimum_size = Vector2(96, 96)
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)
	var title := Label.new()
	title.text = "CAMPAIGN"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_title(title, 48, Palette.TEXT)
	header.add_child(title)
	var total := StarTotal.new()
	total.earned = _total_stars()
	total.possible = _catalog.entries.size() * StarRating.MAX_STARS
	header.add_child(total)

	_build_card(column)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	for page: Page in _build_pages():
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 18)
		pages.add_child(grid)
		_grids.append(grid)
		_pages.append(page)
		if page.world == null:
			var soon := Label.new()
			soon.text = "New puzzles for this world are being built."
			soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			soon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			soon.custom_minimum_size = Vector2(900, 120)
			UiTheme.style_label(soon, 28, Palette.TEXT_MUTED)
			grid.add_child(soon)
			continue
		for entry: LevelCatalog.Entry in page.world.entries:
			var button := _level_tile(entry, WorldTheme.for_world(page.world.id))
			var level_id := entry.level_id
			button.pressed.connect(func() -> void: level_chosen.emit(level_id))
			grid.add_child(button)
			_level_buttons[level_id] = button
	show_world(_initial_world())


func _build_card(column: VBoxContainer) -> void:
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(_on_card_input)
	column.add_child(_card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(stack)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 560)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(stage)
	if _diorama == null:
		_diorama = DioramaView.new()
	_diorama.release()
	stage.add_child(_diorama)
	_diorama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_diorama.set_framing(1.55)
	for entry: Array in [[_previous, -1, Control.PRESET_CENTER_LEFT], [_next, 1, Control.PRESET_CENTER_RIGHT]]:
		var arrow: IconButton = entry[0]
		arrow.custom_minimum_size = Vector2(88, 88)
		arrow.size = Vector2(88, 88)
		arrow.set_anchors_and_offsets_preset(entry[2] as Control.LayoutPreset, Control.PRESET_MODE_KEEP_SIZE)
		var step: int = entry[1]
		arrow.pressed.connect(func() -> void: show_world(_world_index + step))
		stage.add_child(arrow)
	_next.pivot_offset = Vector2(44, 44)
	_next.rotation = PI
	UiTheme.style_label(_world_number, 24, Palette.TEXT_MUTED)
	_world_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_world_number)
	UiTheme.style_title(_world_title, 52, Palette.TEXT)
	_world_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_world_title)
	UiTheme.style_label(_world_tagline, 28, Color(Palette.TEXT, 0.75))
	_world_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_world_tagline)
	UiTheme.style_label(_world_progress, 28, Palette.MECHANISM_AMBER)
	_world_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_world_progress)


## Shows world page `index` (clamped): its card, sky and level grid. Pages follow the seven
## worlds of docs/07; worlds without levels yet show a display-only board and "Coming soon".
func show_world(index: int) -> void:
	_world_index = clampi(index, 0, _pages.size() - 1)
	var page := _pages[_world_index]
	var world_theme := WorldTheme.for_world(page.id)
	for i: int in _grids.size():
		_grids[i].visible = i == _world_index
	_backdrop.theme_data = world_theme
	_card.add_theme_stylebox_override("panel", UiTheme.panel(world_theme.accent, 34))
	_world_number.text = "WORLD %d" % _number_of(page.id)
	_world_title.text = page.title
	_world_title.add_theme_color_override("font_color", world_theme.accent.lightened(0.45))
	_world_tagline.text = world_theme.tagline
	if page.world == null:
		_world_progress.text = "Coming soon"
	else:
		var sealed := 0
		var stars := 0
		for entry: LevelCatalog.Entry in page.world.entries:
			if _progress.best_actions(entry.level_id) >= 0:
				sealed += 1
				stars += _level_stars.get(entry.level_id, 0)
		_world_progress.text = "%d / %d sealed   ·   %d / %d stars" % [sealed, page.world.entries.size(), stars,
			page.world.entries.size() * StarRating.MAX_STARS]
	_previous.disabled = _world_index == 0
	_next.disabled = _world_index == _pages.size() - 1
	if page.diorama_path != "":
		_diorama.show_level(page.diorama_path)


func current_world_index() -> int:
	return _world_index


func page_count() -> int:
	return _pages.size()


## True when page `index` is a world with no levels yet.
func is_coming_soon(index: int) -> bool:
	return _pages[index].world == null


## The page holding the first unlocked level not yet completed (else the first page).
func _initial_world() -> int:
	for i: int in _pages.size():
		if _pages[i].world == null:
			continue
		for entry: LevelCatalog.Entry in _pages[i].world.entries:
			if _progress.best_actions(entry.level_id) < 0 and Progression.is_unlocked(_catalog, _progress, entry.level_id):
				return i
	return 0


## Every world of docs/07 in order: catalog worlds with their levels, the rest as "Coming soon"
## when a showcase board exists. Catalog worlds outside that list are appended (never dropped).
func _build_pages() -> Array[Page]:
	var pages: Array[Page] = []
	var used: Dictionary[String, bool] = {}
	for id: String in WorldTheme.ALL_WORLDS:
		var world: LevelCatalog.World = null
		for candidate: LevelCatalog.World in _catalog.worlds:
			if candidate.id == id:
				world = candidate
		if world != null:
			pages.append(Page.from_world(world))
			used[id] = true
		elif WorldTheme.showcase_path(id) != "":
			var page := Page.new()
			page.id = id
			page.title = WorldTheme.for_world(id).title
			page.diorama_path = WorldTheme.showcase_path(id)
			pages.append(page)
	for world: LevelCatalog.World in _catalog.worlds:
		if not used.has(world.id):
			pages.append(Page.from_world(world))
	return pages


## "world_02_…" → 2.
static func _number_of(world_id: String) -> int:
	var parts := world_id.split("_")
	return int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0


func _on_card_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_drag_start = button.position
		_dragging = true
	elif _dragging:
		_dragging = false
		var drag := button.position - _drag_start
		if absf(drag.x) >= SWIPE_DISTANCE and absf(drag.x) > absf(drag.y):
			show_world(_world_index + (1 if drag.x < 0.0 else -1))


## A tile: big number, title, then stars / "Best N" or a lock with "Locked".
func _level_tile(entry: LevelCatalog.Entry, world_theme: WorldTheme) -> Button:
	var unlocked := Progression.is_unlocked(_catalog, _progress, entry.level_id)
	var best := _progress.best_actions(entry.level_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 236)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	if unlocked:
		var style := UiTheme.box(UiTheme.GLASS, Color(world_theme.accent, 0.55 if best < 0 else 0.3), 26)
		if best < 0:
			style.shadow_color = Color(world_theme.accent, 0.3)
			style.shadow_size = 12
		button.add_theme_stylebox_override("normal", style)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var number := Label.new()
	number.text = str(entry.order + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_title(number, 64, world_theme.accent.lightened(0.5) if unlocked else Color(Palette.TEXT_MUTED, 0.4))
	column.add_child(number)
	var title := Label.new()
	title.name = "Title"
	title.text = entry.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTheme.style_label(title, 24, Palette.TEXT if unlocked else Color(Palette.TEXT_MUTED, 0.5))
	column.add_child(title)
	var detail := Label.new()
	detail.name = "Detail"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_label(detail, 22, Palette.TEXT_MUTED)
	var earned := 0
	if not unlocked:
		var lock := LockMark.new()
		lock.custom_minimum_size = Vector2(0, 40)
		column.add_child(lock)
		detail.text = "Locked"
		detail.visible = false  # The lock icon says it; the text stays for tests and screen readers.
	elif best >= 0:
		var stars := StarRating.new()
		stars.name = "Stars"
		stars.custom_minimum_size = Vector2(150, 40)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		earned = Progression.stars(best, entry.target_actions, entry.optimal_actions)
		stars.earned = earned
		column.add_child(stars)
		detail.text = "Best %d" % best
	column.add_child(detail)
	_level_texts[entry.level_id] = PackedStringArray(["%d.  %s" % [entry.order + 1, entry.title], detail.text])
	_level_stars[entry.level_id] = earned
	return button


func _total_stars() -> int:
	var total := 0
	for entry: LevelCatalog.Entry in _catalog.entries:
		var best := _progress.best_actions(entry.level_id)
		if best >= 0:
			total += Progression.stars(best, entry.target_actions, entry.optimal_actions)
	return total


## The tile's texts as ["N.  Title", "Best N" / "Locked" / ""] (for tests).
func row_texts(level_id: String) -> PackedStringArray:
	return _level_texts.get(level_id, PackedStringArray())


func row_stars(level_id: String) -> int:
	return _level_stars.get(level_id, 0)


func _apply_safe_area() -> void:
	UiTheme.apply_safe_margins(_margin, MARGIN)


## Level ids in display order, across all worlds (for tests).
func listed_level_ids() -> PackedStringArray:
	return PackedStringArray(_level_buttons.keys())


func level_button(level_id: String) -> Button:
	return _level_buttons.get(level_id)


class LockMark:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		IconButton.draw_icon(self, IconButton.Icon.LOCK, size * 0.5, 15.0, Color(Palette.TEXT_MUTED, 0.6))


## "★ 7 / 45" in the header.
class StarTotal:
	extends Control

	var earned := 0
	var possible := 0

	func _init() -> void:
		custom_minimum_size = Vector2(210, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := get_theme_default_font()
		var text := "%d / %d" % [earned, possible]
		draw_string(font, Vector2(70, size.y * 0.5 + 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.TEXT)
		StarRating.draw_star(self, Vector2(40, size.y * 0.5), 22.0, Palette.MECHANISM_AMBER)


## One page of the world carousel.
class Page:
	extends RefCounted

	var id := ""
	var title := ""
	## null for a world with no levels yet.
	var world: LevelCatalog.World
	var diorama_path := ""

	static func from_world(source: LevelCatalog.World) -> Page:
		var page := Page.new()
		page.id = source.id
		page.title = source.title
		page.world = source
		page.diorama_path = source.entries.back().path if not source.entries.is_empty() else ""
		return page
