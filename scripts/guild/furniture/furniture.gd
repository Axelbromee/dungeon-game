@tool
class_name KitFurniture
extends KitPiece
## Guild furniture from KayKit models, always scaled evenly (never
## stretched): the height in `size` sets the scale and the footprint follows
## the model (shelves: the width sets it). Collision matches the model.
## Front (the side you sit on / face) is +Z.

enum Kind { TABLE, CHAIR, BENCH, BARREL, CRATE, SHELF }

@export var kind: Kind = Kind.TABLE
## Height Y sets the scale. Width X picks the table model and the bench
## length; shelves scale from width X and stand Y tall.
@export var size: Vector3 = Vector3(1.6, 0.78, 0.9)
## Shelf only: number of shelf boards.
@export_range(1, 8) var shelf_count: int = 4
## Shelf only: fill the shelves with bottles, candles and coins.
@export var shelf_items: bool = true


func _build() -> void:
	match kind:
		Kind.TABLE:
			_table()
		Kind.CHAIR:
			_chair()
		Kind.BENCH:
			_bench()
		Kind.BARREL:
			_barrel()
		Kind.CRATE:
			_crate()
		Kind.SHELF:
			_shelf()


func _table() -> void:
	# The KayKit table closest in shape (table_long runs along Z, so it's
	# turned when the table is long along X). All KayKit tables are 1 m
	# tall, so the height sets the scale.
	var s := size.y
	var ratio := maxf(size.x, size.z) / maxf(minf(size.x, size.z), 0.01)
	var model := "table_long"
	var turn := 90.0 if size.x > size.z else 0.0
	if ratio < 1.4:
		model = "table_small" if maxf(size.x, size.z) < 1.2 else "table_medium"
		turn = 0.0
	add_model(kk(model), s, Vector3.ZERO, turn)
	_model_collision(kk(model), s, turn)


func _chair() -> void:
	# The KayKit chair's back is at +X; turned so it's at -Z like before.
	var s := (size.y + 0.5) / 1.23
	add_model(kk("chair"), s, Vector3.ZERO, 90.0)
	_model_collision(kk("chair"), s, 90.0)


func _bench() -> void:
	# No KayKit bench: a row of KayKit stools along X, `size.x` long.
	var s := size.y / 0.5
	var stool := 0.75 * s
	var count := maxi(roundi(size.x / (stool + 0.1)), 1)
	var step := size.x / count
	for i in count:
		add_model(kk("stool"), s, Vector3(-size.x * 0.5 + (i + 0.5) * step, 0, 0), 90.0 * (i % 2))
	add_collision_box(Vector3(size.x, size.y, stool), Vector3(0, size.y * 0.5, 0))


func _barrel() -> void:
	var s := size.y / 1.02
	add_model(kk("barrel_small"), s, Vector3.ZERO)
	var shape := CylinderShape3D.new()
	shape.radius = 0.5 * s
	shape.height = size.y
	_collision(shape, Vector3(0, size.y * 0.5, 0), Vector3.ZERO, null)


func _crate() -> void:
	var s := size.y
	add_model(kk("box_small"), s, Vector3.ZERO)
	add_collision_box(Vector3.ONE * s, Vector3(0, s * 0.5, 0))


func _shelf() -> void:
	# A stack of KayKit wall shelves (board + brackets), scaled evenly to
	# the width, backs against -Z. The lowest one leaves room for brackets.
	var w := size.x
	var h := size.y
	var src := KitPiece.model_aabb(kk("shelf_large"))
	var s := w / src.size.x
	var depth := src.size.z * s
	var back := -depth * 0.5
	var boards: Array[float] = []
	for i in shelf_count:
		var y := h - 0.15 if shelf_count == 1 else lerpf(0.45, h - 0.15, float(i) / (shelf_count - 1))
		boards.append(y)
		add_model(kk("shelf_large"), s, Vector3(0, y - src.size.y * s, back + depth * 0.5))
	if shelf_items:
		_fill_shelf(boards, w, depth)
	add_collision_box(Vector3(w, h, depth), Vector3(0, h * 0.5, 0))


## A box collider matching a model's bounds at scale `s` (turned 0 or 90).
func _model_collision(path: String, s: float, turn: float) -> void:
	var box := KitPiece.model_aabb(path)
	var extent := box.size * s
	if absf(fmod(turn, 180.0)) > 1.0:
		extent = Vector3(extent.z, extent.y, extent.x)
	add_collision_box(extent, Vector3(0, extent.y * 0.5, 0))


const SHELF_ITEMS := [
	["bottle_A_brown", 0.24], ["bottle_A_green", 0.24], ["bottle_A_labeled_brown", 0.24],
	["bottle_B_green", 0.2], ["bottle_C_brown", 0.18], ["candle", 0.16],
	["candle_melted", 0.12], ["coin_stack_small", 0.08],
]


## KayKit bottles, candles and coins along each board (board tops at y).
func _fill_shelf(boards: Array[float], width: float, depth: float) -> void:
	var rng := make_rng(7)
	for y in boards:
		var x := -width * 0.5 + 0.12
		while x < width * 0.5 - 0.15:
			if rng.randf() < 0.2:
				x += rng.randf_range(0.08, 0.2)  # Gap.
				continue
			var pick: Array = SHELF_ITEMS[rng.randi() % SHELF_ITEMS.size()]
			var path := kk(pick[0])
			var item_h: float = pick[1]
			var src := KitPiece.model_aabb(path)
			var half_w := maxf(src.size.x, src.size.z) * item_h / maxf(src.size.y, 0.001) * 0.5
			add_model_sized(path, Vector3(x + half_w, y, 0.0), item_h, rng.randf_range(0.0, 360.0))
			x += half_w * 2.0 + 0.03
