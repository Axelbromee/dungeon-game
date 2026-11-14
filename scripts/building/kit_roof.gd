@tool
class_name KitRoof
extends KitPiece
## Ceiling with wooden beams underneath. One Medieval Village wooden floor
## tile per 2 m cell, turned face down; beams are the pack's roof log,
## scaled evenly to 2 m and laid end to end across X. Origin at FLOOR level in the middle of
## the area; the ceiling's underside is at `height`, so it lines up with
## walls of the same height. Spans tiles_x x tiles_z cells.

@export_range(1, 32) var tiles_x: int = 1
@export_range(1, 32) var tiles_z: int = 1
@export var height: float = 4.0
## Collision thickness above `height`.
@export var thickness: float = 0.12
## Not used: the beams are the log model's size (kept so existing scenes load).
@export var beam_width: float = 0.2
## Not used: the beams are the log model's size (kept so existing scenes load).
@export var beam_depth: float = 0.24
## Beam rows per grid cell (running along X). 0 = no beams.
@export_range(0, 4) var beams_per_tile: int = 1

## Ceiling tile (Floor_WoodDark: 2 x 0.02 x 2 m), face down.
const TILE_MODEL := "Floor_WoodDark"
const TILE_DEPTH := 0.02
## Beam: Roof_Log (1.15 x 1.39 x 10.7 m, along Z) scaled evenly to 2 m long.
const BEAM_MODEL := "Roof_Log"
const BEAM_SCALE := 2.0 / 10.7
const BEAM_DEPTH := 1.39 * BEAM_SCALE


func _build() -> void:
	var size_x := tiles_x * GRID
	var size_z := tiles_z * GRID
	add_collision_box(Vector3(size_x, thickness, size_z), Vector3(0, height + thickness * 0.5, 0))
	for ix in tiles_x:
		for iz in tiles_z:
			var centre := Vector3(-size_x * 0.5 + (ix + 0.5) * GRID, height, -size_z * 0.5 + (iz + 0.5) * GRID)
			var flip := Basis(Vector3.RIGHT, PI)
			add_model_xform(mv(TILE_MODEL), Transform3D(flip, centre + Vector3.UP * TILE_DEPTH * 0.5))
	var rows := tiles_z * beams_per_tile
	for i in rows:
		var z := -size_z * 0.5 + (i + 0.5) * size_z / rows
		for ix in tiles_x:
			var x := -size_x * 0.5 + (ix + 0.5) * GRID
			add_model(mv(BEAM_MODEL), BEAM_SCALE, Vector3(x, height - BEAM_DEPTH, z), 90.0)
