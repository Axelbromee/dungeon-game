@tool
class_name KitRailing
extends KitPiece
## Railing along X: KayKit stone barriers at their real size (4 m pieces, a
## 2 m half piece for the rest; 1.1 m tall, 0.5 m deep). `length` snaps to
## the 2 m grid. Origin at floor level in the middle.
## The barrier pieces are open at their ends, so each end gets a KayKit
## column as a post. Turn a post off where another railing's post already
## stands on the same corner, or where the end goes into a wall.

@export var length: float = 2.0
## Not used: the barrier is 1.1 m tall (kept so existing scenes load).
@export var height: float = 1.1
## Not used by the KayKit barrier (kept so existing scenes load unchanged).
@export var baluster_spacing: float = 0.2
## Post at the -X end.
@export var post_start: bool = true
## Post at the +X end.
@export var post_end: bool = true

const MODULE := 4.0
const HALF := 2.0
const HEIGHT := 1.1
const DEPTH := 0.5
## KayKit column (0.7 x 1.4 x 0.7) at this even scale: just wider than the
## barrier, so it closes the open end.
const POST_SCALE := 0.8


func _build() -> void:
	var total := maxf(snappedf(length, GRID), GRID)
	var x := -total * 0.5
	var end := total * 0.5 - 0.01
	while x < end:
		if end - x >= MODULE - 0.02:
			add_model(kk("barrier"), 1.0, Vector3(x + MODULE * 0.5, 0, 0))
			x += MODULE
		else:
			add_model(kk("barrier_half"), 1.0, Vector3(x + HALF * 0.5, 0, 0))
			x += HALF
	add_collision_box(Vector3(total, HEIGHT, DEPTH), Vector3(0, HEIGHT * 0.5, 0))
	var post_size := Vector3(0.7, 1.4, 0.7) * POST_SCALE
	for side in [-1.0, 1.0]:
		if (side < 0.0 and not post_start) or (side > 0.0 and not post_end):
			continue
		var at := Vector3(side * total * 0.5, 0, 0)
		add_model(kk("column"), POST_SCALE, at)
		add_collision_box(post_size, at + Vector3.UP * post_size.y * 0.5)
