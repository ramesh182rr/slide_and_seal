class_name GateDefinition
extends RefCounted
## An authored gate (decision D-013): open when ALL `requires` switches are on.
## An inverted gate (D-035) is the exact opposite: closed when they are all on, open otherwise.
## Its state is always derived (SwitchGateResolver), never stored.

var id: String = ""
var position: Vector2i = Vector2i.ZERO
var requires: PackedStringArray = PackedStringArray()
var inverted: bool = false
