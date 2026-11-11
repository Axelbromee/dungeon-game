@tool
class_name KitBed
extends KitPiece
## Wooden bed. E = rest: restores HP, mana and stamina. The headboard is at
## -Z (put it against a wall), you get in from the sides.

@export var width: float = 1.1
@export var length: float = 2.0
@export var height: float = 0.5
@export var headboard_height: float = 1.0


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	var dark := mat("wood_dark")
	var half_w := width * 0.5
	var half_l := length * 0.5
	# Frame and posts.
	add_box(Vector3(width, 0.18, length), Vector3(0, 0.25, 0), mat("wood"), false)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.09, headboard_height, 0.09), Vector3(sx * (half_w - 0.045), headboard_height * 0.5, -half_l + 0.045), dark, false)
		add_box(Vector3(0.09, height + 0.15, 0.09), Vector3(sx * (half_w - 0.045), (height + 0.15) * 0.5, half_l - 0.045), dark, false)
	add_box(Vector3(width - 0.1, headboard_height * 0.6, 0.05), Vector3(0, headboard_height * 0.6, -half_l + 0.04), mat("wood"), false)
	add_box(Vector3(width - 0.1, 0.25, 0.04), Vector3(0, height, half_l - 0.04), mat("wood"), false)
	# Mattress, blanket (foot end), pillow.
	add_box(Vector3(width - 0.14, 0.16, length - 0.14), Vector3(0, height - 0.05, 0), mat("linen"), false)
	add_box(Vector3(width - 0.08, 0.06, length * 0.62), Vector3(0, height + 0.05, length * 0.17), mat("blanket"), false)
	add_box(Vector3(width - 0.06, 0.2, 0.06), Vector3(0, height - 0.04, half_l - 0.18), mat("blanket"), false)
	add_sphere(0.2, Vector3(0, height + 0.08, -half_l + 0.28), mat("linen"), Vector3(1.9, 0.45, 1.0))
	add_collision_box(Vector3(width, height + 0.1, length), Vector3(0, (height + 0.1) * 0.5, 0))


func get_interaction_text() -> String:
	return "Rest"


func interact(player: Player) -> void:
	player.rest()
