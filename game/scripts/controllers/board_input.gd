class_name BoardInput
extends Node
## Turns pointer input on the board into taps and swipes (decision D-012).
## Uses mouse events, which Godot also emulates from single touches; events consumed by HUD
## controls never reach _unhandled_input, so buttons and the board cannot both react.
## Emits intent only; the controller decides what (if anything) happens.

signal tapped(screen_position: Vector2)
## A drag passed the swipe threshold (or changed direction): show a preview.
signal swipe_previewed(start_position: Vector2, direction: Grid.Direction)
## A drag returned inside the threshold: drop the preview.
signal swipe_cancelled
signal swiped(start_position: Vector2, direction: Grid.Direction)
## View gestures (D-032). Presentation only; the controller forwards them to the camera.
signal zoom_requested(factor: float)
signal rotate_requested(degrees: float)
signal turn_requested(clockwise: bool)
signal pan_requested(screen_delta: Vector2)
signal reset_view_requested

## Minimum drag distance (viewport pixels) that counts as a swipe rather than a tap.
const SWIPE_THRESHOLD := 60.0
const WHEEL_ZOOM_STEP := 1.1

## Unit screen vectors of grid UP, RIGHT, DOWN, LEFT (index = Grid.Direction). Set by the controller.
var direction_vectors: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
var enabled: bool = true

var _pressed := false
var _start := Vector2.ZERO
var _direction := -1
## Active touches (index → position) for two-finger gestures.
var _touches: Dictionary[int, Vector2] = {}
## True from the moment a second finger lands until every finger is lifted: single-finger
## taps and swipes are suppressed so lifting the fingers never fires a stray tap.
var _gesture := false
var _gesture_distance := 0.0
var _gesture_angle := 0.0
var _gesture_middle := Vector2.ZERO


## Finger lifts are tracked here too: a lift over a HUD button is consumed by the GUI and would
## otherwise leave a stale touch that turns the next single tap into a "gesture".
func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed:
		_release_touch(touch.index)


func _unhandled_input(event: InputEvent) -> void:
	if handle_event(event):
		get_viewport().set_input_as_handled()


## Returns true when the event was used. Public so tests can feed events directly.
func handle_event(event: InputEvent) -> bool:
	# View gestures are presentation only, so they work even while a move is playing back.
	if _handle_view_event(event):
		return true
	if not enabled:
		_reset()
		return false
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if _gesture:
			return true  # Emulated mouse events from a multi-finger gesture are ignored.
		if button.pressed:
			_pressed = true
			_start = button.position
			_direction = -1
		elif _pressed:
			_finish(button.position)
		return true
	var motion := event as InputEventMouseMotion
	if motion != null and _gesture:
		return true
	if motion != null and _pressed:
		_track(motion.position)
		return true
	return false


## The grid direction whose on-screen vector best matches `drag`.
func classify(drag: Vector2) -> Grid.Direction:
	var best := 0
	var best_dot := -INF
	var unit := drag.normalized()
	for i: int in direction_vectors.size():
		var dot := unit.dot(direction_vectors[i])
		if dot > best_dot:
			best_dot = dot
			best = i
	return best as Grid.Direction


func _track(position: Vector2) -> void:
	var drag := position - _start
	if drag.length() >= SWIPE_THRESHOLD:
		var direction := classify(drag)
		if direction != _direction:
			_direction = direction
			swipe_previewed.emit(_start, direction)
	elif _direction != -1:
		_direction = -1
		swipe_cancelled.emit()


func _finish(position: Vector2) -> void:
	var drag := position - _start
	var start := _start
	_reset()
	if drag.length() >= SWIPE_THRESHOLD:
		swiped.emit(start, classify(drag))
	else:
		tapped.emit(start)


func is_gesture_active() -> bool:
	return _gesture


## Touches, wheel, trackpad and keys that change the view. Returns true when consumed.
func _handle_view_event(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() >= 2:
				if not _gesture:
					_gesture = true
					if _direction != -1:
						swipe_cancelled.emit()
					_reset()
				_begin_gesture_baseline()
		else:
			var was_gesture := _gesture
			_release_touch(touch.index)
			return was_gesture
		return _gesture
	var drag := event as InputEventScreenDrag
	if drag != null:
		if _touches.has(drag.index):
			_touches[drag.index] = drag.position
		if _gesture and _touches.size() >= 2:
			_update_gesture()
			return true
		return _gesture
	var button := event as InputEventMouseButton
	if button != null and button.pressed and \
			(button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		zoom_requested.emit(WHEEL_ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_ZOOM_STEP)
		return true
	var magnify := event as InputEventMagnifyGesture
	if magnify != null:
		zoom_requested.emit(magnify.factor)
		return true
	var trackpad := event as InputEventPanGesture
	if trackpad != null:
		pan_requested.emit(-trackpad.delta * 8.0)
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_Q:
				turn_requested.emit(false)
				return true
			KEY_E:
				turn_requested.emit(true)
				return true
			KEY_R:
				reset_view_requested.emit()
				return true
	return false


func _release_touch(index: int) -> void:
	if not _touches.has(index):
		return
	_touches.erase(index)
	if _touches.size() >= 2:
		_begin_gesture_baseline()
	elif _touches.is_empty():
		_gesture = false


func _gesture_points() -> Array[Vector2]:
	var indices: Array = _touches.keys()
	indices.sort()
	return [_touches[indices[0]], _touches[indices[1]]]


func _begin_gesture_baseline() -> void:
	var points := _gesture_points()
	_gesture_distance = points[0].distance_to(points[1])
	_gesture_angle = (points[1] - points[0]).angle()
	_gesture_middle = (points[0] + points[1]) * 0.5


## Pinch → zoom, twist → free rotation, two-finger drag → pan (all relative to the last update).
func _update_gesture() -> void:
	var points := _gesture_points()
	var distance := points[0].distance_to(points[1])
	var angle := (points[1] - points[0]).angle()
	var middle := (points[0] + points[1]) * 0.5
	if _gesture_distance > 1.0 and distance > 1.0:
		zoom_requested.emit(distance / _gesture_distance)
	var twist := wrapf(angle - _gesture_angle, -PI, PI)
	if absf(twist) > 0.0001:
		# Screen y points down, so a positive angle is a clockwise twist. A positive camera yaw
		# turns the board clockwise on screen, so the board follows the fingers.
		rotate_requested.emit(rad_to_deg(twist))
	if middle != _gesture_middle:
		pan_requested.emit(middle - _gesture_middle)
	_gesture_distance = distance
	_gesture_angle = angle
	_gesture_middle = middle


func _reset() -> void:
	_pressed = false
	_direction = -1
