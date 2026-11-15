class_name RouteDefinition
extends RefCounted
## One authored route segment: an ordered chain of orthogonally adjacent cells (decision D-003).
## Junctions between segments are planned for portals/rotation but not yet supported.

var id: String = ""
var nodes: Array[Vector2i] = []
var checkpoints: Array[CheckpointDefinition] = []


func last_index() -> int:
	return nodes.size() - 1


func checkpoint_at(cell: Vector2i) -> CheckpointDefinition:
	for checkpoint: CheckpointDefinition in checkpoints:
		if checkpoint.position == cell:
			return checkpoint
	return null
