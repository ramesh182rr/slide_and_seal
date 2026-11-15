class_name RotatingSectionDefinition
extends RefCounted
## An authored rotating section (decisions D-017 – D-020): a square of cells that turns in
## quarter turns. Its contents are authored at turn 0; current positions are derived from
## PuzzleState.section_turns (clockwise quarter turns, mod 4).

var id: String = ""
## Top-left cell and side length (square).
var origin: Vector2i = Vector2i.ZERO
var size: int = 2
var allow_clockwise: bool = true
var allow_counterclockwise: bool = true


func contains(cell: Vector2i) -> bool:
	return cell.x >= origin.x and cell.y >= origin.y and cell.x < origin.x + size and cell.y < origin.y + size


func rect() -> Rect2i:
	return Rect2i(origin, Vector2i(size, size))


## Where an authored cell of this section is after `turns` clockwise quarter turns (y points down).
func rotate_cell(cell: Vector2i, turns: int) -> Vector2i:
	var local := cell - origin
	for i: int in posmod(turns, 4):
		local = Vector2i(size - 1 - local.y, local.x)
	return origin + local


## The authored cell that currently sits at `cell` after `turns` (inverse of rotate_cell).
func authored_cell(cell: Vector2i, turns: int) -> Vector2i:
	return rotate_cell(cell, 4 - posmod(turns, 4))
