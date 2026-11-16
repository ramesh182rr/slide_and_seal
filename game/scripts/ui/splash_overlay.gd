class_name SplashOverlay
extends CanvasLayer
## Startup brand reveal (docs/06 §5 "Splash/brand reveal"). It starts exactly where Android's boot
## splash image leaves off (same background, emblem and wordmark), brightens the emblem, shows the
## tagline, then fades away over Home. About 1.6 s; a tap skips it; reduced motion shortens it to a
## quick fade. While shaders are compiling (ShaderWarmup) it holds the first frame with a slim
## loading bar, then plays. Menu presentation only: no gameplay is affected.

signal finished

const TAGLINE := "Reconfigure reality. Control the maze. Complete the seal."

var reduced_motion := false
var _root := Control.new()
var _progress := 0.0
var _done := false
var _warmup: ShaderWarmup
var _playing := false


## Hold the opening frame (with a loading bar) until `warmup` finishes.
func wait_for(warmup: ShaderWarmup) -> void:
	_warmup = warmup


func _ready() -> void:
	layer = 100
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_paint)
	_root.gui_input.connect(_on_input)
	add_child(_root)
	if _warmup != null and not _warmup.is_finished():
		_warmup.finished.connect(_play)
		set_process(true)
	else:
		_play()


func _process(_delta: float) -> void:
	if not _playing:
		_root.queue_redraw()


func _play() -> void:
	if _playing or _done:
		return
	_playing = true
	set_process(false)
	var tween := create_tween()
	if reduced_motion:
		tween.tween_interval(0.3)
	else:
		tween.tween_method(_set_progress, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.15)
	tween.tween_property(_root, "modulate:a", 0.0, 0.25 if reduced_motion else 0.45)
	tween.tween_callback(_finish)


func is_finished() -> bool:
	return _done


func _set_progress(value: float) -> void:
	_progress = value
	_root.queue_redraw()


func _on_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and _playing:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _paint() -> void:
	var view := _root.size
	_root.draw_rect(Rect2(Vector2.ZERO, view), BrandMark.SPLASH_BG)
	# The boot image is a square fitted to the screen's width ("keep" stretch), centred.
	var s := minf(view.x, view.y)
	var layout := BrandMark.splash_layout(view * 0.5, s)
	var centre: Vector2 = layout[0]
	var radius: float = layout[1]
	# A widening halo as the core wakes.
	for i: int in 12:
		var f := 1.0 - float(i) / 12.0
		_root.draw_circle(centre, radius * (1.2 + 1.8 * _progress) * f, Color(BrandMark.RING, 0.018 * _progress))
	BrandMark.draw_emblem(_root, centre, radius, BrandMark.RING.lerp(Color.WHITE, 0.35 * _progress))
	BrandMark.draw_wordmark(_root, layout[2], layout[3])
	var font := ThemeDB.fallback_font
	var tag_size := int(s * 0.03)
	var width := font.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
	_root.draw_string(font, Vector2(view.x * 0.5 - width * 0.5, (layout[2] as Vector2).y + s * 0.08), TAGLINE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color(0.85, 0.92, 1.0, 0.75 * _progress))
	if not _playing and _warmup != null and is_instance_valid(_warmup):
		var bar := Rect2(view.x * 0.5 - s * 0.2, (layout[2] as Vector2).y + s * 0.1, s * 0.4, 4.0)
		_root.draw_rect(bar, Color(BrandMark.RING, 0.15))
		_root.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _warmup.progress(), bar.size.y)), Color(BrandMark.RING, 0.8))
