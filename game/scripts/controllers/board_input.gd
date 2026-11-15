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

## Minimum drag distance (viewport pixels) that counts as a swipe rather than a tap.
const SWIPE_THRESHOLD := 60.0

## Unit screen vectors of grid UP, RIGHT, DOWN, LEFT (index = Grid.Direction). Set by the controller.
var direction_vectors: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
var enabled: bool = true

var _pressed := false
var _start := Vector2.ZERO
var _direction := -1


func _unhandled_input(event: InputEvent) -> void:
	if handle_event(event):
		get_viewport().set_input_as_handled()


## Returns true when the event was used. Public so tests can feed events directly.
func handle_event(event: InputEvent) -> bool:
	if not enabled:
		_reset()
		return false
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pressed = true
			_start = button.position
			_direction = -1
		elif _pressed:
			_finish(button.position)
		return true
	var motion := event as InputEventMouseMotion
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


func _reset() -> void:
	_pressed = false
	_direction = -1
