class_name RouteDefinition
extends RefCounted
## One authored route segment: an ordered chain of orthogonally adjacent cells (decision D-003).
## A segment ends either at the destination or on a portal entry, which links it to the segment
## starting at that portal's exit. The loader computes and validates these links.

var id: String = ""
var nodes: Array[Vector2i] = []
var checkpoints: Array[CheckpointDefinition] = []
## Set by the loader when this segment ends on a portal entry: the portal and the segment it leads to.
var exit_portal_id: String = ""
var next_route_id: String = ""


func last_index() -> int:
	return nodes.size() - 1


func checkpoint_at(cell: Vector2i) -> CheckpointDefinition:
	for checkpoint: CheckpointDefinition in checkpoints:
		if checkpoint.position == cell:
			return checkpoint
	return null
