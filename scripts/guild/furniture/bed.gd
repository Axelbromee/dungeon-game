@tool
class_name KitBed
extends KitPiece
## Wooden bed (Fantasy Props Bed_Twin1). E = rest: restores HP, mana and stamina. The headboard is at
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
	# Bed_Twin1 (frame, mattress, blanket, pillows: 1.88 x 0.81 x 2.41 m),
	# scaled evenly from the length; headboard at -Z.
	var path := fp("Bed_Twin1")
	var src := model_aabb(path)
	var s := length / src.size.z
	add_model(path, s, Vector3.ZERO)
	add_collision_box(src.size * s, Vector3(0, src.size.y * s * 0.5, 0))


func get_interaction_text() -> String:
	return "Rest"


func interact(player: Player) -> void:
	player.rest()
