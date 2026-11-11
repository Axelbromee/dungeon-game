@tool
class_name KitFloor
extends KitPiece
## Floor made of 2 m tiles: wooden planks or stone slabs. Origin at the
## centre of the area; walkable top surface at y = 0.

enum Style { PLANK, STONE }

@export var style: Style = Style.PLANK
@export_range(1, 32) var tiles_x: int = 1
@export_range(1, 32) var tiles_z: int = 1
@export var thickness: float = 0.2
## Plank style: planks across one tile (they run along Z).
@export_range(2, 12) var planks_per_tile: int = 5
## Stone style: slabs per tile edge (2 = 4 slabs per tile).
@export_range(1, 4) var slabs_per_tile: int = 2
## Gap between planks / slabs (shows the dark layer underneath).
@export var gap: float = 0.02


func _build() -> void:
	var size_x := tiles_x * GRID
	var size_z := tiles_z * GRID
	add_collision_box(Vector3(size_x, thickness, size_z), Vector3(0, -thickness * 0.5, 0))
	# Dark under-layer that shows through the gaps.
	var under := "wood_dark" if style == Style.PLANK else "stone_wall"
	add_box(Vector3(size_x, thickness * 0.5, size_z), Vector3(0, -thickness * 0.75, 0), mat(under), false)
	if style == Style.PLANK:
		_build_planks(size_x, size_z)
	else:
		_build_slabs(size_x, size_z)


func _build_planks(size_x: float, size_z: float) -> void:
	var rng := make_rng(1)
	var count := tiles_x * planks_per_tile
	var plank_width := size_x / count
	var top := thickness * 0.5
	var materials := ["plank_a", "plank_b", "plank_c"]
	for i in count:
		var x := -size_x * 0.5 + (i + 0.5) * plank_width
		# Staggered joints: each plank row is split into random lengths.
		var z := -size_z * 0.5
		while z < size_z * 0.5 - 0.01:
			var length := minf(rng.randf_range(1.2, 2.8), size_z * 0.5 - z)
			add_box(Vector3(plank_width - gap, top, length - gap),
				Vector3(x, -top * 0.5, z + length * 0.5),
				mat(materials[rng.randi() % materials.size()]), false)
			z += length


func _build_slabs(size_x: float, size_z: float) -> void:
	var rng := make_rng(2)
	var count_x := tiles_x * slabs_per_tile
	var count_z := tiles_z * slabs_per_tile
	var slab_x := size_x / count_x
	var slab_z := size_z / count_z
	var top := thickness * 0.5
	for ix in count_x:
		for iz in count_z:
			var lift := rng.randf_range(-0.008, 0.008)
			var material := "stone" if rng.randf() < 0.75 else "stone_pillar"
			add_box(Vector3(slab_x - gap, top, slab_z - gap),
				Vector3(-size_x * 0.5 + (ix + 0.5) * slab_x, -top * 0.5 + lift, -size_z * 0.5 + (iz + 0.5) * slab_z),
				mat(material), false)
