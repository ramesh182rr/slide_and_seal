class_name CameraRig
extends Node3D
## Orthographic isometric camera that frames the whole board inside the area left free by the HUD.
## Presentation only (docs/05 §2, D-031): the view can be rotated freely, zoomed and panned by the
## player, but never changes the puzzle. Emits `view_changed` so screen-direction consumers
## (swipe classification, arrow panels) can follow the new projection.

signal view_changed

const DEFAULT_YAW_DEGREES := 45.0
const PITCH_DEGREES := -50.0
const CAMERA_DISTANCE := 40.0
## Extra space around the board, as a fraction of its projected size.
const PADDING := 1.08
const MIN_ZOOM := 1.0
const MAX_ZOOM := 3.0
const BUTTON_TURN_DEGREES := 90.0
const BUTTON_TURN_SECONDS := 0.3

## Fractions of screen height reserved for the HUD (bottom includes the mechanism panel).
@export var top_reserved: float = 0.17
@export var bottom_reserved: float = 0.3

var _camera: Camera3D
var _board_size := Vector2i.ZERO
var _yaw := DEFAULT_YAW_DEGREES
var _zoom := 1.0
## Pan in the camera plane (world units along the view's right/up), relative to the fitted centre.
var _pan := Vector2.ZERO
## Fitted (zoom 1) visible width and the board's projected half extents, for pan clamping.
var _fit_size := 1.0
var _half_extents := Vector2.ZERO
var _turn_tween: Tween
## Reduced motion / tests: view turns apply immediately instead of animating.
var instant: bool = false


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.far = CAMERA_DISTANCE * 3.0
	add_child(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_reframe)


func get_camera() -> Camera3D:
	return _camera


func yaw_degrees() -> float:
	return _yaw


func zoom_level() -> float:
	return _zoom


func pan_offset() -> Vector2:
	return _pan


## Unit screen-space vector of one grid step in `direction` (screen y points down).
func screen_vector(direction: Grid.Direction) -> Vector2:
	var origin := BoardCoords.board_center(_board_size)
	var step := BoardCoords.cell_to_world(Grid.offset(direction))
	return (_camera.unproject_position(origin + step) - _camera.unproject_position(origin)).normalized()


func frame_board(board_size: Vector2i) -> void:
	_board_size = board_size
	_reframe()


## Free rotation (twist gesture): turn the view by `degrees` immediately.
func rotate_view(degrees: float) -> void:
	_yaw = fposmod(_yaw + degrees, 360.0)
	_apply()


## Button rotation: a short animated 90° turn.
func turn_view(clockwise: bool) -> void:
	if _turn_tween != null and _turn_tween.is_running():
		_turn_tween.kill()
	var from := _yaw
	# A positive yaw turns the board clockwise on screen.
	var delta := BUTTON_TURN_DEGREES if clockwise else -BUTTON_TURN_DEGREES
	if instant:
		rotate_view(delta)
		return
	_turn_tween = create_tween()
	_turn_tween.tween_method(func(t: float) -> void:
		_yaw = fposmod(from + delta * t, 360.0)
		_apply(), 0.0, 1.0, BUTTON_TURN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Multiplies the zoom by `factor` (pinch / wheel / buttons), clamped to MIN_ZOOM..MAX_ZOOM.
func zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_apply()


## Pans by a screen-space drag (pixels): the board follows the fingers.
func pan_by_screen(delta: Vector2) -> void:
	var viewport_width := maxf(get_viewport().get_visible_rect().size.x, 1.0)
	var world_per_pixel := _camera.size / viewport_width
	_pan += Vector2(-delta.x, delta.y) * world_per_pixel
	_apply()


func reset_view() -> void:
	if _turn_tween != null and _turn_tween.is_running():
		_turn_tween.kill()
	_yaw = DEFAULT_YAW_DEGREES
	_zoom = 1.0
	_pan = Vector2.ZERO
	_apply()


func _apply() -> void:
	_reframe()
	view_changed.emit()


func _reframe() -> void:
	if _board_size == Vector2i.ZERO or _camera == null:
		return
	rotation_degrees = Vector3(PITCH_DEGREES, _yaw, 0.0)
	position = BoardCoords.board_center(_board_size)
	# Project the board's bounding box onto the camera's right/up axes at the current yaw.
	var right := basis.x
	var up := basis.y
	var half := Vector3(_board_size.x, 0.0, _board_size.y) * 0.5 * BoardCoords.CELL_SIZE
	var min_r := INF
	var max_r := -INF
	var min_u := INF
	var max_u := -INF
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for height: float in [-0.6, BoardRenderer3D.WALL_HEIGHT]:
				var corner := Vector3(half.x * sx, height, half.z * sz)
				min_r = minf(min_r, corner.dot(right))
				max_r = maxf(max_r, corner.dot(right))
				min_u = minf(min_u, corner.dot(up))
				max_u = maxf(max_u, corner.dot(up))
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var usable := 1.0 - top_reserved - bottom_reserved
	# KEEP_WIDTH: `size` is the visible width; visible height is size / aspect.
	_fit_size = maxf((max_r - min_r) * PADDING, (max_u - min_u) * PADDING * aspect / usable)
	_half_extents = Vector2(max_r - min_r, max_u - min_u) * 0.5
	_camera.size = _fit_size / _zoom
	# Keep part of the board on screen: the view centre may move at most to the board's edge.
	_pan = _pan.clamp(-_half_extents, _half_extents)
	var visible_height := _fit_size / aspect
	# Centre the board in the band between the HUD areas (at zoom 1), then apply the pan.
	var band_offset := (bottom_reserved - top_reserved) * 0.5 * visible_height / _zoom
	_camera.position = Vector3((max_r + min_r) * 0.5 + _pan.x, (max_u + min_u) * 0.5 - band_offset + _pan.y,
		CAMERA_DISTANCE)
