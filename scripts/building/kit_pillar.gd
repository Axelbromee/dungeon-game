@tool
class_name KitPillar
extends KitPiece
## Freestanding support pillar: KayKit stone pillars stacked to `height`
## (one per ~4 m), each scaled evenly so the stack ends exactly at `height`.
## A 4 m pillar is 1.5 m wide; a shorter or taller row is evenly smaller or
## bigger.

@export var height: float = 4.0
## Not used: the width follows the height (kept so existing scenes load).
@export var size: float = 0.3
## Not used by the KayKit pillar (kept so existing scenes load unchanged).
@export var base_height: float = 0.4

const ROW := 4.0
const WIDTH := 1.5


func _build() -> void:
	var rows := maxi(roundi(height / ROW), 1)
	var s := height / (rows * ROW)
	for r in rows:
		add_model(kk("pillar"), s, Vector3(0, r * ROW * s, 0))
	add_collision_box(Vector3(WIDTH * s, height, WIDTH * s), Vector3(0, height * 0.5, 0))
