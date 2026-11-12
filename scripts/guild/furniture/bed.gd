@tool
class_name KitBed
extends KitPiece
## Wooden bed (KayKit). E = rest: restores HP, mana and stamina. The headboard is at
## -Z (put it against a wall), you get in from the sides.

## Not used: the width follows the length (kept so existing scenes load).
@export var width: float = 1.0
@export var length: float = 2.0
## Not used: the height follows the length (kept so existing scenes load).
@export var height: float = 0.5
## Not used: the height follows the length (kept so existing scenes load).
@export var headboard_height: float = 1.0


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	# KayKit bed (frame, mattress, blanket, pillow), scaled evenly from the
	# length (1.5 x 1.06 x 3 m model); headboard at -Z.
	var s := length / 3.0
	add_model(kk("bed_frame"), s, Vector3.ZERO)
	add_collision_box(Vector3(1.5, 1.06, 3.0) * s, Vector3(0, 0.53 * s, 0))


func get_interaction_text() -> String:
	return "Rest"


func interact(player: Player) -> void:
	player.rest()
