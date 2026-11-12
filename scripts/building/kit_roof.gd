@tool
class_name KitRoof
extends KitPiece
## Ceiling with wooden beams underneath. One KayKit ceiling tile per 2 m
## cell (the 4 m tile at an even half scale); beams are KayKit wooden
## planks laid end to end across X. Origin at FLOOR level in the middle of
## the area; the ceiling's underside is at `height`, so it lines up with
## walls of the same height. Spans tiles_x x tiles_z cells.

@export_range(1, 32) var tiles_x: int = 1
@export_range(1, 32) var tiles_z: int = 1
@export var height: float = 4.0
## Collision thickness above `height`.
@export var thickness: float = 0.12
## Not used: the beams are KayKit planks (kept so existing scenes load).
@export var beam_width: float = 0.2
## Not used: the beams are KayKit planks (kept so existing scenes load).
@export var beam_depth: float = 0.24
## Beam rows per grid cell (running along X). 0 = no beams.
@export_range(0, 4) var beams_per_tile: int = 1

const TILE_SCALE := 0.5
## Wooden plank (Wood_Plank_*: 0.4 x 0.15 x 1.5 m) scaled evenly to 2 m.
const PLANK_SCALE := 2.0 / 1.5
const PLANK_DEPTH := 0.15 * PLANK_SCALE
const PLANKS := ["Wood_Plank_A", "Wood_Plank_B", "Wood_Plank_C"]


func _build() -> void:
	var size_x := tiles_x * GRID
	var size_z := tiles_z * GRID
	add_collision_box(Vector3(size_x, thickness, size_z), Vector3(0, height + thickness * 0.5, 0))
	for ix in tiles_x:
		for iz in tiles_z:
			var centre := Vector3(-size_x * 0.5 + (ix + 0.5) * GRID, height, -size_z * 0.5 + (iz + 0.5) * GRID)
			add_model(kk("ceiling_tile"), TILE_SCALE, centre)
	var rng := make_rng(5)
	var rows := tiles_z * beams_per_tile
	for i in rows:
		var z := -size_z * 0.5 + (i + 0.5) * size_z / rows
		for ix in tiles_x:
			var x := -size_x * 0.5 + (ix + 0.5) * GRID
			var plank := "res://KayKit/Assets3/gltf/%s.gltf" % PLANKS[rng.randi() % PLANKS.size()]
			add_model(plank, PLANK_SCALE, Vector3(x, height - PLANK_DEPTH, z), 90.0)
