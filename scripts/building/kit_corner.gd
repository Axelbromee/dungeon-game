@tool
class_name KitCorner
extends KitPiece
## Corner post where two walls meet (place it on a grid corner). Stone column
## with a timber cap, slightly thicker than the walls so the joint is hidden.

@export var height: float = 3.0
@export var size: float = 0.45
@export var cap_height: float = 0.16


func _build() -> void:
	add_box(Vector3(size, height - cap_height, size), Vector3(0, (height - cap_height) * 0.5, 0), mat("stone_pillar"))
	add_box(Vector3(size + 0.06, cap_height, size + 0.06), Vector3(0, height - cap_height * 0.5, 0), mat("wood_dark"), false)
	add_box(Vector3(size + 0.08, 0.12, size + 0.08), Vector3(0, 0.06, 0), mat("stone_wall"), false)
