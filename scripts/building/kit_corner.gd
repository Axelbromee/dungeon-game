@tool
class_name KitCorner
extends KitPiece
## Corner post where two walls meet (place it on a grid corner): Medieval
## Village brick quoins, two per storey turned around the corner so it's
## brick on all sides, scaled evenly to the 4 m storey (about 1.3 x 1.4 m),
## which covers the joint of two 1 m thick walls. `height` rounds to
## whole storeys.

@export var height: float = 4.0
## Not used: the post size comes from the model (kept so existing scenes load).
@export var size: float = 1.5
## Not used by the model post (kept so existing scenes load unchanged).
@export var cap_height: float = 0.16

const ROW := 4.0


func _build() -> void:
	var rows := maxi(roundi(height / ROW), 1)
	var footprint := KitPillar.add_post(self, ROW, rows)
	add_collision_box(Vector3(footprint.x, rows * ROW, footprint.y), Vector3(0, rows * ROW * 0.5, 0))
