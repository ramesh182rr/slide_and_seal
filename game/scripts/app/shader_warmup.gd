class_name ShaderWarmup
extends Node
## Compiles every shader the game uses while the startup splash is on screen.
## In the Compatibility (OpenGL) renderer a shader variant compiles synchronously the first time
## it is drawn, which froze the first level load and the first visit to each world for up to a
## second on phones. This renders, off screen, one gameplay scene and one diorama per world (the
## real scenes, so the same variants: lights, shadows, fog, glow, every material). Materials are
## kept by MaterialLibrary's static cache, so the compiled shaders stay alive afterwards.
## Presentation only; it never touches progress or settings.

signal finished

const GAMEPLAY_SCENE := preload("res://scenes/gameplay/gameplay_root.tscn")
## Frames each scene stays on screen: the first drawn frame compiles everything it uses.
const FRAMES_PER_STEP := 1

var _level_paths: PackedStringArray = []
var _viewport := SubViewport.new()
var _step := 0
var _frame := 0
var _current: Node
var _done := false


var _shared: DioramaView
var _restore_path := ""


## One level per world is enough: shaders depend on what is drawn, not on the layout.
## With `shared`, the diorama steps build into that view, so its cache holds every world's board
## before the player first opens the campaign.
func setup(level_paths: PackedStringArray, shared: DioramaView = null) -> void:
	_level_paths = level_paths
	_shared = shared


func _ready() -> void:
	_viewport.size = Vector2i(270, 480)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)


func is_finished() -> bool:
	return _done


## 0..1 for the splash.
func progress() -> float:
	var total := _level_paths.size() * 2
	return 1.0 if total == 0 else clampf(float(_step) / total, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _done:
		return
	if _current == null:
		if _step >= _level_paths.size() * 2:
			_finish()
			return
		_current = _make_step(_step)
		_viewport.add_child(_current)
		_frame = 0
		return
	_frame += 1
	if _frame >= FRAMES_PER_STEP:
		_viewport.remove_child(_current)
		_current.queue_free()
		_current = null
		_step += 1


func _make_step(step: int) -> Node:
	var path := _level_paths[step / 2]
	if step % 2 == 0:
		var gameplay: GameplayController = GAMEPLAY_SCENE.instantiate()
		gameplay.level_path = path
		gameplay.instant_playback = true
		gameplay.quit_on_leave = false
		return gameplay
	if _shared != null and _shared.is_inside_tree():
		if _restore_path == "":
			_restore_path = _shared.current_level_path()
		_shared.show_level(path)
		return Node.new()  # Placeholder: the shared view (under the splash) does the drawing.
	var diorama := DioramaView.new()
	diorama.size = Vector2(_viewport.size)
	diorama.ready.connect(func() -> void: diorama.show_level(path))
	return diorama


func _finish() -> void:
	if _shared != null and _restore_path != "" and is_instance_valid(_shared):
		_shared.show_level(_restore_path)
	_done = true
	finished.emit()
	queue_free()
