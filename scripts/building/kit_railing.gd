@tool
class_name KitRailing
extends KitPiece
## Railing along X: Medieval Village wooden balcony railings at their real
## size (2 m pieces with a post at each end; 1.23 m tall). `length` snaps to
## the 2 m grid. Origin at floor level in the middle.

@export var length: float = 2.0
## Not used: the railing is 1.23 m tall (kept so existing scenes load).
@export var height: float = 1.1
## Not used by the model railing (kept so existing scenes load unchanged).
@export var baluster_spacing: float = 0.2
## Not used: every railing piece has its own end posts (kept so existing scenes load).
@export var post_start: bool = true
## Not used: every railing piece has its own end posts (kept so existing scenes load).
@export var post_end: bool = true

const MODULE := 2.0
const MODEL := "Balcony_Simple_Straight"


func _build() -> void:
	var total := maxf(snappedf(length, GRID), GRID)
	var path := mv(MODEL)
	var src := model_aabb(path)
	var x := -total * 0.5
	while x < total * 0.5 - 0.01:
		add_model(path, 1.0, Vector3(x + MODULE * 0.5, 0, 0))
		x += MODULE
	add_collision_box(Vector3(total, src.size.y, src.size.z), Vector3(0, src.size.y * 0.5, 0))
