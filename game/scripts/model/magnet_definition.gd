class_name MagnetDefinition
extends RefCounted
## An authored magnet (decisions D-026 – D-029). Solid like an emitter. Its current polarity is
## PuzzleState.magnet_positive; flipping it fires one pulse (MagnetResolver).

var id: String = ""
var position: Vector2i = Vector2i.ZERO
var initially_positive: bool = true
