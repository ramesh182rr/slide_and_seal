class_name ReflectorDefinition
extends RefCounted
## An authored two-sided mirror (D-022). `slash` = "/" orientation, otherwise "\". The current
## orientation is PuzzleState.reflector_slash (flipped by FLIP_REFLECTOR). Solid like an emitter.

var id: String = ""
var position: Vector2i = Vector2i.ZERO
var initially_slash: bool = true


## Beam direction after bouncing off a mirror. "/" runs bottom-left to top-right (grid y down).
static func reflect(direction: Grid.Direction, slash: bool) -> Grid.Direction:
	match direction:
		Grid.Direction.RIGHT:
			return Grid.Direction.UP if slash else Grid.Direction.DOWN
		Grid.Direction.LEFT:
			return Grid.Direction.DOWN if slash else Grid.Direction.UP
		Grid.Direction.UP:
			return Grid.Direction.RIGHT if slash else Grid.Direction.LEFT
	return Grid.Direction.LEFT if slash else Grid.Direction.RIGHT  # DOWN
