class_name AudioDirector
extends Node
## All sound in the game: short effects and one looping ambient bed per world. Every sound is
## synthesised by tools/generate_audio.py (original, project-owned).
##
## One director lives under AppRoot; everything else calls the static helpers, which do nothing
## when there is no director (tests, scenes run on their own) or the setting is off. Sound never
## affects the puzzle: it only reports what the simulation already decided.

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const SFX_NAMES: PackedStringArray = ["tap", "move", "reject", "run", "step", "land", "slide", "gate", "switch",
	"turn", "checkpoint", "complete", "star", "undo", "whoosh"]
const VOICES := 8
const MUSIC_DB := -17.0
## Effects sit a little under full scale so several can overlap without distorting.
const SFX_DB := -5.0
const FADE_SECONDS := 0.8
## The same effect is not restarted within this many milliseconds (many blocks landing together).
const RETRIGGER_MS := 45

static var _instance: AudioDirector

var sound_enabled := true
var music_enabled := true:
	set(value):
		music_enabled = value
		_apply_music()

var _streams: Dictionary[String, AudioStream] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played: Dictionary[String, int] = {}
var _music_a := AudioStreamPlayer.new()
var _music_b := AudioStreamPlayer.new()
var _music_current: AudioStreamPlayer
var _music_world := ""
var _fade: Tween


func _ready() -> void:
	_instance = self
	# A safety net on the master bus: stacked sounds are held just under full scale, never clipped.
	var has_limiter := false
	for i: int in AudioServer.get_bus_effect_count(0):
		has_limiter = has_limiter or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, limiter)
	for effect: String in SFX_NAMES:
		_streams[effect] = load("%s/%s.wav" % [SFX_DIR, effect])
	for i: int in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	for player: AudioStreamPlayer in [_music_a, _music_b]:
		player.volume_db = -60.0
		add_child(player)
	_music_current = _music_a
	# Every button in the game ticks when pressed, wherever it was made.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		button.button_down.connect(_play.bind("tap", 1.0, 0.0))


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


## Plays effect `name`. `pitch` scales its pitch (1.0 = as recorded); `volume_db` trims it.
static func play(effect: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if _instance != null:
		_instance._play(effect, pitch, volume_db)


## Cross-fades to the ambient loop of `world_id` ("world_03_push_protocol" → world_03).
static func set_world(world_id: String) -> void:
	if _instance != null:
		_instance._set_world(world_id)


static func is_active() -> bool:
	return _instance != null


## Effects played so far, by name (tests and diagnostics).
func play_count(effect: String) -> int:
	return _counts.get(effect, 0)


func current_world() -> String:
	return _music_world


var _counts: Dictionary[String, int] = {}


func _play(effect: String, pitch: float, volume_db: float) -> void:
	if not sound_enabled or not _streams.has(effect):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(effect, -1000)) < RETRIGGER_MS:
		return
	_last_played[effect] = now
	_counts[effect] = int(_counts.get(effect, 0)) + 1
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = _streams[effect]
	voice.pitch_scale = clampf(pitch, 0.5, 2.5)
	voice.volume_db = SFX_DB + volume_db
	voice.play()


func _set_world(world_id: String) -> void:
	var parts := world_id.split("_")
	var key := "world_%s" % parts[1] if parts.size() > 1 else "world_01"
	if key == _music_world:
		return
	_music_world = key
	_apply_music()


## Starts, swaps or stops the ambient loop to match the world and the music setting.
func _apply_music() -> void:
	if not is_inside_tree():
		return
	if _fade != null and _fade.is_running():
		_fade.kill()
	var old := _music_current
	if not music_enabled or _music_world == "":
		_fade = create_tween()
		_fade.tween_property(old, "volume_db", -60.0, FADE_SECONDS)
		_fade.tween_callback(old.stop)
		return
	var path := "%s/%s.wav" % [MUSIC_DIR, _music_world]
	if not ResourceLoader.exists(path):
		return
	var next := _music_b if old == _music_a else _music_a
	next.stream = load(path)
	next.volume_db = -60.0
	next.play()
	_music_current = next
	_fade = create_tween().set_parallel()
	_fade.tween_property(next, "volume_db", MUSIC_DB, FADE_SECONDS)
	_fade.tween_property(old, "volume_db", -60.0, FADE_SECONDS)
	_fade.chain().tween_callback(old.stop)
