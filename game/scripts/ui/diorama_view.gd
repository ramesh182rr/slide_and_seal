class_name DioramaView
extends SubViewportContainer
## A live miniature of a world (docs/06 §6): one of its levels on its floating island, slowly
## turning, rendered in its own 3D world over a transparent background. Decoration only: it shows
## the level's starting state and never runs a puzzle.

const TURN_DEGREES_PER_SECOND := 6.0
const PITCH_DEGREES := -32.0

var _viewport := SubViewport.new()
var _board: BoardRenderer3D
var _camera := Camera3D.new()
var _pivot := Node3D.new()
var _environment := WorldEnvironment.new()
var _key := DirectionalLight3D.new()
var _fill := DirectionalLight3D.new()
var _level_path := ""
var _boards: Dictionary[String, BoardRenderer3D] = {}
## Zoom: the fraction of the view the board spans (smaller = more island and sky around it).
var framing := 1.45
var animate := true


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	# Same budget as the main view on phones (project setting rendering/scaling_3d/scale.mobile).
	_viewport.scaling_3d_scale = ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_environment.environment = environment
	_viewport.add_child(_environment)
	_key.rotation = Vector3(-0.95, 0.5, 0)
	_key.light_energy = 1.25
	_viewport.add_child(_key)
	_fill.rotation = Vector3(-0.5, -2.4, 0)
	_fill.light_energy = 0.45
	_viewport.add_child(_fill)
	_viewport.add_child(_pivot)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.far = 200.0
	_pivot.add_child(_camera)


## Shows `level_path` (a level JSON) in its world's theme. Boards are built once per level and
## kept (hidden when not shown), so paging back to a world costs nothing. Does nothing if the
## level fails to load.
func show_level(level_path: String) -> void:
	if level_path == _level_path:
		return
	_level_path = level_path
	if _board != null:
		_board.visible = false
		_board.set_process(false)
	if _boards.has(level_path):
		_board = _boards[level_path]
	else:
		var loaded := LevelLoader.load_file(level_path)
		if not loaded.is_ok():
			push_warning("Diorama: %s could not be loaded" % level_path)
			_board = null
			return
		_board = BoardRenderer3D.new()
		_board.animate = animate
		_viewport.add_child(_board)
		_board.build(loaded.level, PuzzleSession.new(loaded.level).get_state())
		# Symbols are for play; in a diorama they are clutter.
		for label: Node in _board.find_children("*", "Label3D", true, false):
			(label as Label3D).visible = false
		_boards[level_path] = _board
	_board.visible = true
	_board.set_process(true)
	_board.world_theme().apply_to_stage(_environment.environment, _key, _fill)
	var size := _board.level().board_size
	var span := maxf(size.x, size.y)
	_pivot.position = BoardCoords.board_center(size) + Vector3(0, -span * 0.18, 0)
	_pivot.rotation_degrees = Vector3(0, 30, 0)
	_camera.rotation_degrees = Vector3(PITCH_DEGREES, 0, 0)
	_camera.position = Vector3(0, 0, 60).rotated(Vector3.RIGHT, deg_to_rad(PITCH_DEGREES))
	_camera.size = span * framing
	_camera.make_current()
	_board.set_view_yaw(_pivot.rotation_degrees.y)


## Changes the zoom of the current and future boards (Home and Campaign share one view).
func set_framing(value: float) -> void:
	framing = value
	if _board != null:
		var size := _board.level().board_size
		_camera.size = maxf(size.x, size.y) * framing


## Detaches from the current parent so a screen can be freed without freeing this view.
func release() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)


func current_level_path() -> String:
	return _level_path


func cached_board_count() -> int:
	return _boards.size()


func world_theme() -> WorldTheme:
	return _board.world_theme() if _board != null else null


func _process(delta: float) -> void:
	if animate and _board != null:
		_pivot.rotate_y(deg_to_rad(TURN_DEGREES_PER_SECOND) * delta)
		_board.set_view_yaw(_pivot.rotation_degrees.y)
