class_name EmitterDefinition
extends RefCounted
## An authored energy emitter (D-025). Fires a beam in `direction` while all `requires` switches
## are on (always, when empty). Solid: blocks and the core cannot enter its cell.

var id: String = ""
var position: Vector2i = Vector2i.ZERO
var direction: Grid.Direction = Grid.Direction.RIGHT
var requires: PackedStringArray = PackedStringArray()
