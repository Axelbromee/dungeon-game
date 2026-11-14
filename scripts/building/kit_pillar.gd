@tool
class_name KitPillar
extends KitPiece
## Freestanding support pillar: Medieval Village brick quoins
## (Corner_ExteriorWide_Brick, two turned 180 degrees around the centre so
## the post is brick on all sides), stacked to `height` (one per ~4 m), each
## scaled evenly so the stack ends exactly at `height`. A 4 m pillar is
## about 1 m wide; a shorter or taller row is evenly smaller or bigger.

@export var height: float = 4.0
## Not used: the width follows the height (kept so existing scenes load).
@export var size: float = 0.3
## Not used by the model pillar (kept so existing scenes load unchanged).
@export var base_height: float = 0.4

const ROW := 4.0
const MODEL := "Corner_ExteriorWide_Brick"


func _build() -> void:
	var rows := maxi(roundi(height / ROW), 1)
	var row_h := height / rows
	var footprint := add_post(self, row_h, rows)
	add_collision_box(Vector3(footprint.x, height, footprint.y), Vector3(0, height * 0.5, 0))


## Brick post of `rows` stacked quoin pairs, each `row_h` tall (scaled
## evenly). Returns the footprint (x, z).
static func add_post(piece: KitPiece, row_h: float, rows: int, origin: Vector3 = Vector3.ZERO) -> Vector2:
	var path := KitPiece.mv(MODEL)
	var src := KitPiece.model_aabb(path)
	var s := row_h / src.size.y
	for r in rows:
		for turn in [0.0, PI]:
			var basis := Basis(Vector3.UP, turn).scaled_local(Vector3.ONE * s)
			# Turn around the quoin's corner (model origin) and line up its bottom.
			var offset := Vector3(0, origin.y + r * row_h - src.position.y * s, 0)
			piece.add_model_xform(path, Transform3D(basis, Vector3(origin.x, 0, origin.z) + offset))
	return post_footprint(row_h)


## Footprint (x, z) of a post whose rows are `row_h` tall.
static func post_footprint(row_h: float) -> Vector2:
	var src := KitPiece.model_aabb(KitPiece.mv(MODEL))
	var s := row_h / src.size.y
	var reach := Vector2.ZERO
	for corner in [src.position, src.end]:
		reach.x = maxf(reach.x, absf(corner.x) * s)
		reach.y = maxf(reach.y, absf(corner.z) * s)
	return reach * 2.0
