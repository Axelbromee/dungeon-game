@tool
class_name KitRailing
extends KitPiece
## Wooden railing along X: posts, top and bottom rails, balusters.
## Origin at floor level in the middle.

@export var length: float = 2.0
@export var height: float = 1.0
@export var baluster_spacing: float = 0.2


func _build() -> void:
	var half := length * 0.5
	var wood := mat("wood")
	var dark := mat("wood_dark")
	var posts := maxi(int(ceil(length / 1.0)), 1) + 1
	for i in posts:
		var x := -half + length * i / float(posts - 1)
		add_box(Vector3(0.1, height + 0.08, 0.1), Vector3(x, (height + 0.08) * 0.5, 0), dark, false)
	add_box(Vector3(length, 0.07, 0.11), Vector3(0, height, 0), wood, false)
	add_box(Vector3(length, 0.05, 0.07), Vector3(0, 0.12, 0), wood, false)
	var count := int(length / baluster_spacing)
	for i in range(1, count):
		var x := -half + i * baluster_spacing
		add_box(Vector3(0.035, height - 0.16, 0.035), Vector3(x, height * 0.5 + 0.04, 0), wood, false)
	add_collision_box(Vector3(length, height, 0.12), Vector3(0, height * 0.5, 0))
