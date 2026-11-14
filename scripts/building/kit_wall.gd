@tool
class_name KitWall
extends KitPiece
## Wall made of Medieval Village brick walls at their real size (uniform
## scale 1): 2 m wide, 3.12 m tall modules, one on each face so both faces
## are brick. Plain wall is 1 m thick (the two faces 1 m apart, brick in
## between), so things placed against the old 1 m walls still sit flush.
## A storey is 4 m: the 0.88 m above each module is a band in the walls'
## own brick material. `height` rounds to whole 4 m storeys (stacked
## rows). Plain, with windows, or with a doorway (put a KitDoor in it).
## Window and doorway walls are at least 4 m wide (two grid cells): in the
## middle 4 m of the ground storey the modules sit back to back (0.62 m, a
## recessed bay): two window modules side by side, or the doorway module
## with 1 m of brick either side; a wider wall is filled with plain wall.
## Origin at floor level in the middle of the wall; the wall runs along X,
## its thickness along Z.

enum Style { PLAIN, WINDOW, DOORWAY }

@export var style: Style = Style.PLAIN
## Snaps to the 2 m grid (window and doorway walls are at least 4 m).
@export var width: float = 2.0
## Rounds to whole 4 m storeys.
@export var height: float = 4.0
## Not used: the thickness comes from the models (kept so existing scenes load).
@export var thickness: float = 1.0
## Not used: the band height comes from the 4 m storey (kept so existing scenes load).
@export var plinth_height: float = 0.7
## Not used (kept so existing scenes load unchanged).
@export var timber_frame: bool = true
@export_group("Window")
## Not used: the window comes from the model (kept for old scenes).
@export var window_width: float = 0.9
@export var window_height: float = 1.0
@export var window_sill: float = 1.1
@export_group("Doorway")
## Not used for the opening, which comes from the model (1.3 x 2.47 m).
## SceneDoor still uses door_height for its sign when it's higher.
@export var door_width: float = 1.3
@export var door_height: float = 2.47

## One storey, and the wall module (Wall_UnevenBrick_*: 2 x 3.12 m, body
## 0.2 m thick between z -0.2 and 0, trims out to -0.31 / +0.09).
const ROW := 4.0
const MODULE := 2.0
const HALF := 2.0
const WALL_H := 3.12
const BODY := 0.2
const BODY_CENTRE := -0.1
## Plain wall: the faces 1 m apart. The recessed bay: two modules back to
## back (depth over the trims, and the solid body).
const DEPTH := 1.0
const BAY_DEPTH := 0.62
const BODY_DEPTH := 2.0 * BODY
const STRAIGHT := "Wall_UnevenBrick_Straight"
const WINDOW_MODEL := "Wall_UnevenBrick_Window_Wide_Round"
const DOOR_MODEL := "Wall_UnevenBrick_Door_Round"
## Walkable doorway opening in the doorway module (half width, top).
const MODEL_DOOR_HALF_WIDTH := 0.6
const MODEL_DOOR_TOP := 2.4
## Kept for SceneDoor (no door part in the doorway module).
const DOOR_PART := ""


func _build() -> void:
	var rows := storeys()
	var w := wall_width()
	var half := w * 0.5
	var band := brick_material()
	var bay := style != Style.PLAIN
	var side := (w - 2.0 * MODULE) * 0.5  # Plain wall either side of the bay.
	for r in rows:
		var y := r * ROW
		if r == 0 and bay:
			_plain_run(-half, side, y)
			_plain_run(MODULE, side, y)
			if style == Style.WINDOW:
				_module(WINDOW_MODEL, -MODULE * 0.5, y, 0.0)
				_module(WINDOW_MODEL, MODULE * 0.5, y, 0.0)
			else:
				_module(DOOR_MODEL, 0.0, y, 0.0)
				for sx in [-1.0, 1.0]:
					add_box(Vector3(1.0, WALL_H, BODY_DEPTH), Vector3(sx * 1.5, y + WALL_H * 0.5, 0), band, false)
			# Bands: thin over the bay, full depth either side.
			add_box(Vector3(2.0 * MODULE, ROW - WALL_H, BODY_DEPTH), Vector3(0, y + (WALL_H + ROW) * 0.5, 0), band, false)
			for sx in [-1.0, 1.0]:
				if side > 0.01:
					add_box(Vector3(side, ROW - WALL_H, DEPTH), Vector3(sx * (MODULE + side * 0.5), y + (WALL_H + ROW) * 0.5, 0), band, false)
		else:
			_plain_run(-half, w, y)
			add_box(Vector3(w, ROW - WALL_H, DEPTH), Vector3(0, y + (WALL_H + ROW) * 0.5, 0), band, false)
	# Collision matches the models: 1 m thick plain wall, the thinner bay,
	# and the doorway's opening.
	var total := rows * ROW
	if not bay:
		add_collision_box(Vector3(w, total, DEPTH), Vector3(0, total * 0.5, 0))
		return
	for sx in [-1.0, 1.0]:
		if side > 0.01:
			add_collision_box(Vector3(side, total, DEPTH), Vector3(sx * (MODULE + side * 0.5), total * 0.5, 0))
	if total > ROW:
		add_collision_box(Vector3(2.0 * MODULE, total - ROW, DEPTH), Vector3(0, (total + ROW) * 0.5, 0))
	if style == Style.DOORWAY:
		var opening := doorway_opening()
		var jamb := MODULE - opening.x * 0.5
		for sx in [-1.0, 1.0]:
			add_collision_box(Vector3(jamb, ROW, BAY_DEPTH), Vector3(sx * (MODULE - jamb * 0.5), ROW * 0.5, 0))
		add_collision_box(Vector3(opening.x, ROW - opening.y, BAY_DEPTH), Vector3(0, (ROW + opening.y) * 0.5, 0))
	else:
		# Windows block like glass.
		add_collision_box(Vector3(2.0 * MODULE, ROW, BAY_DEPTH), Vector3(0, ROW * 0.5, 0))


## One wall module centred at x, a copy on each face (brick out, plaster
## sides facing each other), their brick faces `apart` metres apart; with
## a gap between them it's filled with brick.
func _module(model: String, x: float, y: float, apart: float) -> void:
	var path := mv(model)
	var gap := maxf(apart - BODY_DEPTH, 0.0)
	for turn in [0.0, PI]:
		var basis := Basis(Vector3.UP, turn)
		# Model body spans z -0.2..0 (brick face at 0): push the face out to apart / 2.
		var face := maxf(apart * 0.5, BODY)
		add_model_xform(path, Transform3D(basis, Vector3(x, y, 0) + basis * Vector3(0, 0, face)))
	if gap > 0.01:
		add_box(Vector3(MODULE, WALL_H, gap), Vector3(x, y + WALL_H * 0.5, 0), brick_material(), false)


## Plain wall modules (1 m thick) from x0 along `length`.
func _plain_run(x0: float, length: float, y: float) -> void:
	var x := x0
	var end := x0 + length - 0.01
	while x < end:
		_module(STRAIGHT, x + MODULE * 0.5, y, DEPTH)
		x += MODULE


## The walls' brick, mapped in world space, for bands and fillers.
static func brick_material() -> Material:
	return KitPiece.pack_box_material(KitPiece.mv(STRAIGHT), "MI_UnevenBrick", 2.0)


## Number of stacked 4 m rows.
func storeys() -> int:
	return maxi(roundi(height / ROW), 1)


## Width snapped to the grid (window / doorway walls are at least 4 m and
## keep the feature centred on whole modules).
func wall_width() -> float:
	var w := maxf(snappedf(width, GRID), GRID)
	if style != Style.PLAIN:
		w = maxf(w, 2.0 * MODULE)
		if fmod(w - 2.0 * MODULE, 2.0 * MODULE) > 0.01:
			w += MODULE
	return w


## Walkable doorway size (width, height).
func doorway_opening() -> Vector2:
	return Vector2(MODEL_DOOR_HALF_WIDTH * 2.0, MODEL_DOOR_TOP)
