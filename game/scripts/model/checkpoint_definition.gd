class_name CheckpointDefinition
extends RefCounted
## An authored interaction checkpoint on a route. Immutable after loading.

var id: String = ""
var position: Vector2i = Vector2i.ZERO
## When true the core stops on entering this cell; otherwise it is only recorded as reached.
var auto_pause: bool = true
## Mechanism names the player may use while paused here (see LevelLoader.MECHANISM_NAMES).
var allowed_mechanisms: PackedStringArray = PackedStringArray()
