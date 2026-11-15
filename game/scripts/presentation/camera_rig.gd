class_name CameraRig
extends Node3D
## Orthographic isometric camera that frames the whole board inside the area left free by the HUD.
## Presentation only (docs/05 §2): a stable camera during ordinary moves.

const YAW_DEGREES := 45.0
const PITCH_DEGREES := -50.0
const CAMERA_DISTANCE := 40.0
## Extra space around the board, as a fraction of its projected size.
const PADDING := 1.08

## Fractions of screen height reserved for the HUD (bottom includes the mechanism panel).
@export var top_reserved: float = 0.17
@export var bottom_reserved: float = 0.3

var _camera: Camera3D
var _board_size := Vector2i.ZERO


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


## Unit screen-space vector of one grid step in `direction` (screen y points down).
func screen_vector(direction: Grid.Direction) -> Vector2:
	var origin := BoardCoords.board_center(_board_size)
	var step := BoardCoords.cell_to_world(Grid.offset(direction))
	return (_camera.unproject_position(origin + step) - _camera.unproject_position(origin)).normalized()


func frame_board(board_size: Vector2i) -> void:
	_board_size = board_size
	_reframe()


func _reframe() -> void:
	if _board_size == Vector2i.ZERO:
		return
	rotation_degrees = Vector3(PITCH_DEGREES, YAW_DEGREES, 0.0)
	position = BoardCoords.board_center(_board_size)
	# Project the board's bounding box onto the camera's right/up axes.
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
	_camera.size = maxf((max_r - min_r) * PADDING, (max_u - min_u) * PADDING * aspect / usable)
	var visible_height := _camera.size / aspect
	# Centre the board in the band between the HUD areas.
	var band_offset := (bottom_reserved - top_reserved) * 0.5 * visible_height
	_camera.position = Vector3((max_r + min_r) * 0.5, (max_u + min_u) * 0.5 - band_offset, CAMERA_DISTANCE)
