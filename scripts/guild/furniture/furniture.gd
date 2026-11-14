@tool
class_name KitFurniture
extends KitPiece
## Guild furniture from Fantasy Props models, always scaled evenly (never
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
	# Table_Large (the pack's only table: 2.85 x 0.81 x 1.1 m, long along X),
	# scaled evenly from the height; turned when the table is long along Z.
	var path := fp("Table_Large")
	var s := size.y / model_aabb(path).size.y
	var turn := 90.0 if size.z > size.x * 1.01 else 0.0
	add_model(path, s, Vector3.ZERO, turn)
	_model_collision(path, s, turn)


func _chair() -> void:
	# Chair_1 (back at -Z), as tall as before: the seat height + 0.5 m.
	var path := fp("Chair_1")
	var s := (size.y + 0.5) / model_aabb(path).size.y
	add_model(path, s, Vector3.ZERO)
	_model_collision(path, s, 0.0)


func _bench() -> void:
	# Benches (2.78 x 0.53 x 0.53 m) scaled evenly from the seat height,
	# as many in a row along X as fit `size.x` best.
	var path := fp("Bench")
	var src := model_aabb(path)
	var s := size.y / src.size.y
	var one := src.size.x * s
	var count := maxi(roundi(size.x / one), 1)
	for i in count:
		add_model(path, s, Vector3((i - (count - 1) * 0.5) * one, 0, 0))
	add_collision_box(Vector3(one * count, size.y, src.size.z * s), Vector3(0, size.y * 0.5, 0))


func _barrel() -> void:
	var path := fp("Barrel")
	var src := model_aabb(path)
	var s := size.y / src.size.y
	add_model(path, s, Vector3.ZERO)
	var shape := CylinderShape3D.new()
	shape.radius = src.size.x * 0.5 * s
	shape.height = size.y
	_collision(shape, Vector3(0, size.y * 0.5, 0), Vector3.ZERO, null)


func _crate() -> void:
	var path := fp("Crate_Wooden")
	var s := size.y / model_aabb(path).size.y
	add_model(path, s, Vector3.ZERO)
	_model_collision(path, s, 0.0)


func _shelf() -> void:
	# A stack of Shelf_Simple wall shelves (board + brackets), scaled evenly to
	# the width, backs against -Z. The lowest one leaves room for brackets.
	var w := size.x
	var h := size.y
	var shelf := fp("Shelf_Simple")
	var src := KitPiece.model_aabb(shelf)
	var s := w / src.size.x
	var depth := src.size.z * s
	var back := -depth * 0.5
	var boards: Array[float] = []
	for i in shelf_count:
		var y := h - 0.15 if shelf_count == 1 else lerpf(0.45, h - 0.15, float(i) / (shelf_count - 1))
		boards.append(y)
		add_model(shelf, s, Vector3(0, y - src.size.y * s, back + depth * 0.5))
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
	["Bottle_1", 0.24], ["Potion_2", 0.24], ["Potion_4", 0.22],
	["Potion_1", 0.18], ["SmallBottles_1", 0.14], ["Candle_2", 0.16],
	["Candle_1", 0.12], ["Coin_Pile", 0.06],
]


## Bottles, candles and coins along each board (board tops at y).
func _fill_shelf(boards: Array[float], width: float, depth: float) -> void:
	var rng := make_rng(7)
	for y in boards:
		var x := -width * 0.5 + 0.12
		while x < width * 0.5 - 0.15:
			if rng.randf() < 0.2:
				x += rng.randf_range(0.08, 0.2)  # Gap.
				continue
			var pick: Array = SHELF_ITEMS[rng.randi() % SHELF_ITEMS.size()]
			var path := fp(pick[0])
			var item_h: float = pick[1]
			var src := KitPiece.model_aabb(path)
			var half_w := maxf(src.size.x, src.size.z) * item_h / maxf(src.size.y, 0.001) * 0.5
			add_model_sized(path, Vector3(x + half_w, y, 0.0), item_h, rng.randf_range(0.0, 360.0))
			x += half_w * 2.0 + 0.03
