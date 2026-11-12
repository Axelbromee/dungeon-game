@tool
class_name KitCorner
extends KitPiece
## Corner post where two walls meet (place it on a grid corner): the KayKit
## stone pillar at its real size (1.5 m square, 4 m tall per storey), which
## covers the joint of two 1 m thick walls. `height` rounds to whole storeys.

@export var height: float = 4.0
## Not used: the pillar is 1.5 m wide (kept so existing scenes load).
@export var size: float = 1.5
## Not used by the KayKit pillar (kept so existing scenes load unchanged).
@export var cap_height: float = 0.16

const ROW := 4.0
const WIDTH := 1.5


func _build() -> void:
	var rows := maxi(roundi(height / ROW), 1)
	for r in rows:
		add_model(kk("pillar"), 1.0, Vector3(0, r * ROW, 0))
	add_collision_box(Vector3(WIDTH, rows * ROW, WIDTH), Vector3(0, rows * ROW * 0.5, 0))
