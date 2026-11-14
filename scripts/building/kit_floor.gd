@tool
class_name KitFloor
extends KitPiece
## Floor made of 2 m tiles: Medieval Village wooden planks or bricks at their
## real size, one per tile (turned at random so the pattern doesn't
## repeat). Origin at the centre of the area; walkable top surface at y = 0.

enum Style { PLANK, STONE }

@export var style: Style = Style.PLANK
@export_range(1, 32) var tiles_x: int = 1
@export_range(1, 32) var tiles_z: int = 1
## Collision depth below the walkable surface.
@export var thickness: float = 0.2
## Not used by the model tiles (kept so existing scenes load unchanged).
@export_range(2, 12) var planks_per_tile: int = 5
## Not used by the model tiles (kept so existing scenes load unchanged).
@export_range(1, 4) var slabs_per_tile: int = 2
## Not used by the model tiles (kept so existing scenes load unchanged).
@export var gap: float = 0.02

## Visible depth of a tile (Floor_WoodDark / Floor_Brick: 2 x 0.02 x 2 m).
const TILE_DEPTH := 0.02
const PLANK_MODEL := "Floor_WoodDark"
const STONE_MODEL := "Floor_Brick"


func _build() -> void:
	var size_x := tiles_x * GRID
	var size_z := tiles_z * GRID
	add_collision_box(Vector3(size_x, thickness, size_z), Vector3(0, -thickness * 0.5, 0))
	var model := mv(PLANK_MODEL if style == Style.PLANK else STONE_MODEL)
	var rng := make_rng(1 if style == Style.PLANK else 2)
	for ix in tiles_x:
		for iz in tiles_z:
			# Planks keep their direction (turn 0 / 180); slabs turn freely.
			var turn := 180.0 * rng.randi_range(0, 1) if style == Style.PLANK else 90.0 * rng.randi_range(0, 3)
			var centre := Vector3(-size_x * 0.5 + (ix + 0.5) * GRID, -TILE_DEPTH, -size_z * 0.5 + (iz + 0.5) * GRID)
			add_model(model, 1.0, centre, turn)
