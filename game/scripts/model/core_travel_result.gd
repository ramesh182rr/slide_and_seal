class_name CoreTravelResult
extends RefCounted
## Describes one resolved core travel segment, for presentation and analytics.
## The committed state is the authority; this is a read-only description of how it got there.

enum StopReason { CHECKPOINT, BLOCKED, DESTINATION }

## Cells entered, in order (the starting cell is excluded). A portal transit appears as the entry
## cell followed by the exit cell; the exit's index is listed in `portal_steps`.
var path: Array[Vector2i] = []
## Indices into `path` that were reached by teleporting from the previous entry cell (D-015).
var portal_steps: PackedInt32Array = PackedInt32Array()
var stop_reason: StopReason = StopReason.DESTINATION
## Set when stop_reason == CHECKPOINT.
var checkpoint_id: String = ""
## Set when stop_reason == BLOCKED: the occupied cell the core could not enter.
var blocked_cell: Vector2i = Vector2i.ZERO
