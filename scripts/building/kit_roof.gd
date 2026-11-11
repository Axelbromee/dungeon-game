@tool
class_name KitRoof
extends KitPiece
## Ceiling / roof boards with exposed wooden beams underneath. Origin at
## FLOOR level in the middle of the area; the ceiling sits at `height`, so it
## lines up with walls of the same height. Spans tiles_x x tiles_z cells.

@export_range(1, 32) var tiles_x: int = 1
@export_range(1, 32) var tiles_z: int = 1
@export var height: float = 3.0
@export var thickness: float = 0.12
@export var beam_width: float = 0.2
@export var beam_depth: float = 0.24
## Beams per grid cell (running along X).
@export_range(1, 4) var beams_per_tile: int = 1


func _build() -> void:
	var size_x := tiles_x * GRID
	var size_z := tiles_z * GRID
	add_box(Vector3(size_x, thickness, size_z), Vector3(0, height + thickness * 0.5, 0), mat("plank_b"))
	var count := tiles_z * beams_per_tile
	for i in count:
		var z := -size_z * 0.5 + (i + 0.5) * size_z / count
		add_box(Vector3(size_x, beam_depth, beam_width), Vector3(0, height - beam_depth * 0.5, z), mat("wood_dark"), false)
	# Cross joists at the tile edges along Z.
	for i in tiles_x + 1:
		var x := -size_x * 0.5 + i * GRID
		x = clampf(x, -size_x * 0.5 + 0.06, size_x * 0.5 - 0.06)
		add_box(Vector3(0.12, 0.1, size_z), Vector3(x, height - 0.05, 0), mat("wood"), false)
