@tool
class_name FurnitureSpot
extends KitPiece
## Placeholder marking where a future station goes (crafting bench, potion
## station...): a rug outline on the floor and a floating label.

@export var text: String = "Crafting bench\n(coming soon)"
@export var size: Vector2 = Vector2(1.6, 1.0)


func _build() -> void:
	add_box(Vector3(size.x, 0.012, size.y), Vector3(0, 0.006, 0), mat("wood_dark"), false)
	add_box(Vector3(size.x - 0.12, 0.016, size.y - 0.12), Vector3(0, 0.008, 0), mat("cloth_green"), false)
	var label := add_label(text, Vector3(0, 0.9, 0), 32, Color(0.95, 0.88, 0.7, 0.85))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
