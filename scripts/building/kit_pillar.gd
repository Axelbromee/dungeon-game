@tool
class_name KitPillar
extends KitPiece
## Support beam / pillar: timber post on a stone base, iron bands, capital.

@export var height: float = 3.0
@export var size: float = 0.3
@export var base_height: float = 0.4


func _build() -> void:
	add_box(Vector3(size + 0.2, base_height, size + 0.2), Vector3(0, base_height * 0.5, 0), mat("stone_pillar"))
	var post_height := height - base_height - 0.18
	add_box(Vector3(size, post_height, size), Vector3(0, base_height + post_height * 0.5, 0), mat("wood_dark"))
	add_box(Vector3(size + 0.14, 0.18, size + 0.14), Vector3(0, height - 0.09, 0), mat("wood"))
	var iron := mat("iron")
	for y in [base_height + 0.35, height - 0.55]:
		add_box(Vector3(size + 0.03, 0.06, size + 0.03), Vector3(0, y, 0), iron, false)
