class_name GateDefinition
extends RefCounted
## An authored gate (decision D-013): open when ALL `requires` switches are on.
## Its state is always derived (SwitchGateResolver), never stored.

var id: String = ""
var position: Vector2i = Vector2i.ZERO
var requires: PackedStringArray = PackedStringArray()
