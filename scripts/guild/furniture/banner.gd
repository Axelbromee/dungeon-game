@tool
class_name KitBanner
extends KitPiece
## Hanging cloth banner (KayKit), red, blue or green. Origin = the
## middle of the rod (hang it on a wall at about 2.7 m).

enum ClothColor { RED, BLUE, GREEN }

@export var cloth_color: ClothColor = ClothColor.RED
@export var width: float = 0.9
## Not used: the length follows the width (kept so existing scenes load).
@export var length: float = 1.7


const MODELS := ["banner_red", "banner_blue", "banner_green"]


func _build() -> void:
	# KayKit banner (1.5 x 3.2 x 0.31 m with its rod and bracket), scaled
	# evenly from the width; it hangs from the rod at the origin, its back
	# against the wall.
	var s := (width + 0.2) / 1.5
	add_model(kk(MODELS[cloth_color]), s, Vector3(0, 0.1 - 3.2 * s, -0.02 + 0.155 * s))
