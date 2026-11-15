class_name PortalDefinition
extends RefCounted
## An authored portal (decision D-015: carries the core only). Immutable after loading.
## An entry portal (with `exit_id`) sits on the last node of a route segment; the core stepping
## into it continues from the exit portal's cell, the first node of the next segment.

var id: String = ""
var position: Vector2i = Vector2i.ZERO
## Id of the portal the core arrives at; "" for an exit-only portal.
var exit_id: String = ""
## Switch ids that must all be on for the portal to carry the core. Empty = always active.
var requires: PackedStringArray = PackedStringArray()
