class_name CoreTravelResult
extends RefCounted
## Describes one resolved core travel segment, for presentation and analytics.
## The committed state is the authority; this is a read-only description of how it got there.

enum StopReason { CHECKPOINT, BLOCKED, DESTINATION }

## Cells entered, in order (the starting cell is excluded).
var path: Array[Vector2i] = []
var stop_reason: StopReason = StopReason.DESTINATION
## Set when stop_reason == CHECKPOINT.
var checkpoint_id: String = ""
## Set when stop_reason == BLOCKED: the occupied cell the core could not enter.
var blocked_cell: Vector2i = Vector2i.ZERO
