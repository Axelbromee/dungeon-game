@tool
class_name KitWall
extends KitPiece
## Wall made of KayKit dungeon walls at their real size (uniform scale 1):
## 4 m wide, 4 m tall and 1 m thick pieces, with 2 m half walls to fill odd
## grid cells. `height` rounds to whole 4 m storeys (stacked rows).
## Plain, with a window, or with a doorway (put a KitDoor in it). Window and
## doorway pieces are 4 m wide (two grid cells); a wider wall is filled with
## plain wall on both sides.
## Origin at floor level in the middle of the wall; the wall runs along X,
## its thickness along Z.

enum Style { PLAIN, WINDOW, DOORWAY }

@export var style: Style = Style.PLAIN
## Snaps to the 2 m grid (window and doorway walls are at least 4 m).
@export var width: float = 2.0
## Rounds to whole 4 m storeys.
@export var height: float = 4.0
## Not used: the KayKit walls are 1 m thick (kept so existing scenes load).
@export var thickness: float = 1.0
## Not used by the KayKit walls (kept so existing scenes load unchanged).
@export var plinth_height: float = 0.7
## Not used by the KayKit walls (kept so existing scenes load unchanged).
@export var timber_frame: bool = true
@export_group("Window")
## Not used: the window comes from the model (kept for old scenes).
@export var window_width: float = 0.9
@export var window_height: float = 1.0
@export var window_sill: float = 1.1
@export_group("Doorway")
## Not used for the opening, which comes from the model (2.3 x 2.56 m).
## SceneDoor still uses door_height for its sign when it's higher.
@export var door_width: float = 2.3
@export var door_height: float = 2.6

## The KayKit wall module.
const ROW := 4.0
const MODULE := 4.0
const HALF := 2.0
const DEPTH := 1.0
## Walkable doorway opening in the KayKit doorway (half width, arch top
## over the middle).
const MODEL_DOOR_HALF_WIDTH := 1.15
const MODEL_DOOR_TOP := 2.56
const DOOR_PART := "wall_doorway_door"


func _build() -> void:
	var rows := storeys()
	var w := wall_width()
	var half := w * 0.5
	for r in rows:
		var y := r * ROW
		if r == 0 and style != Style.PLAIN:
			# Feature piece in the middle, plain wall either side.
			var side := (w - MODULE) * 0.5
			_plain_run(-half, side, y)
			_plain_run(MODULE * 0.5, side, y)
			if style == Style.WINDOW:
				add_model(kk("wall_window_open"), 1.0, Vector3(0, y, 0))
			else:
				add_model(kk("wall_doorway"), 1.0, Vector3(0, y, 0), 0.0, null, PackedStringArray(), PackedStringArray([DOOR_PART]))
		else:
			_plain_run(-half, w, y)
	# Collision matches the 1 m thick models; doorways keep their opening.
	var total := rows * ROW
	if style == Style.DOORWAY:
		var opening := doorway_opening()
		var side_w := half - opening.x * 0.5
		for sx in [-1.0, 1.0]:
			add_collision_box(Vector3(side_w, total, DEPTH), Vector3(sx * (half - side_w * 0.5), total * 0.5, 0))
		add_collision_box(Vector3(opening.x, total - opening.y, DEPTH), Vector3(0, (total + opening.y) * 0.5, 0))
	else:
		# Windows block like glass.
		add_collision_box(Vector3(w, total, DEPTH), Vector3(0, total * 0.5, 0))


## Plain wall pieces from x0 along `length` (4 m pieces, a 2 m half piece
## for the rest).
func _plain_run(x0: float, length: float, y: float) -> void:
	var x := x0
	var end := x0 + length - 0.01
	while x < end:
		if end - x >= MODULE - 0.02:
			add_model(kk("wall"), 1.0, Vector3(x + MODULE * 0.5, y, 0))
			x += MODULE
		else:
			add_model(kk("wall_half"), 1.0, Vector3(x + HALF * 0.5, y, 0))
			x += HALF


## Number of stacked 4 m rows.
func storeys() -> int:
	return maxi(roundi(height / ROW), 1)


## Width snapped to the grid (window / doorway walls are at least 4 m).
func wall_width() -> float:
	var w := maxf(snappedf(width, GRID), GRID)
	if style != Style.PLAIN:
		w = maxf(w, MODULE)
		# Keep the feature piece centred on whole half-wall pieces.
		if fmod(w - MODULE, 2.0 * HALF) > 0.01:
			w += HALF
	return w


## Walkable doorway size (width, height).
func doorway_opening() -> Vector2:
	return Vector2(MODEL_DOOR_HALF_WIDTH * 2.0, MODEL_DOOR_TOP)
