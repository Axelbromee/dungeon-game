@tool
class_name KitFurniture
extends KitPiece
## Simple guild furniture built from boxes. Pick the kind; sizes are
## exported. Front (the side you sit on / face) is +Z.

enum Kind { TABLE, CHAIR, BENCH, BARREL, CRATE, SHELF }

@export var kind: Kind = Kind.TABLE
## Overall size (meaning per kind: width X, height Y, depth Z).
@export var size: Vector3 = Vector3(1.6, 0.78, 0.9)
## Shelf only: number of shelf boards.
@export_range(1, 8) var shelf_count: int = 4
## Shelf only: fill shelves with books, bottles and jars.
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
	var w := size.x
	var h := size.y
	var d := size.z
	var top := 0.06
	add_box(Vector3(w, top, d), Vector3(0, h - top * 0.5, 0), mat("plank_a"), false)
	add_box(Vector3(w - 0.16, 0.1, d - 0.16), Vector3(0, h - top - 0.05, 0), mat("wood_dark"), false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_box(Vector3(0.08, h - top, 0.08), Vector3(sx * (w * 0.5 - 0.1), (h - top) * 0.5, sz * (d * 0.5 - 0.1)), mat("wood_dark"), false)
	add_collision_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0))


func _chair() -> void:
	var w := size.x
	var seat_h := size.y
	var d := size.z
	add_box(Vector3(w, 0.05, d), Vector3(0, seat_h, 0), mat("plank_a"), false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_box(Vector3(0.05, seat_h, 0.05), Vector3(sx * (w * 0.5 - 0.04), seat_h * 0.5, sz * (d * 0.5 - 0.04)), mat("wood_dark"), false)
		# Back posts continue up at the back (-Z).
		add_box(Vector3(0.05, 0.5, 0.05), Vector3(sx * (w * 0.5 - 0.04), seat_h + 0.27, -d * 0.5 + 0.04), mat("wood_dark"), false)
	for y in [seat_h + 0.25, seat_h + 0.45]:
		add_box(Vector3(w - 0.04, 0.07, 0.03), Vector3(0, y, -d * 0.5 + 0.04), mat("wood"), false)
	add_collision_box(Vector3(w, seat_h + 0.5, d), Vector3(0, (seat_h + 0.5) * 0.5, 0))


func _bench() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	add_box(Vector3(w, 0.06, d), Vector3(0, h - 0.03, 0), mat("plank_b"), false)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.07, h - 0.06, d - 0.04), Vector3(sx * (w * 0.5 - 0.15), (h - 0.06) * 0.5, 0), mat("wood_dark"), false)
	add_box(Vector3(w - 0.3, 0.05, 0.05), Vector3(0, 0.15, 0), mat("wood_dark"), false)
	add_collision_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0))


func _barrel() -> void:
	var radius := size.x * 0.5
	var h := size.y
	add_cylinder(radius * 0.92, h, Vector3(0, h * 0.5, 0), mat("wood"), false, Vector3.ZERO, null, 14)
	add_cylinder(radius, h * 0.55, Vector3(0, h * 0.5, 0), mat("wood"), false, Vector3.ZERO, null, 14)
	for y in [h * 0.15, h * 0.5, h * 0.85]:
		add_cylinder(radius * 1.01 if y == h * 0.5 else radius * 0.95, 0.05, Vector3(0, y, 0), mat("iron"), false, Vector3.ZERO, null, 14)
	add_cylinder(radius * 0.86, 0.02, Vector3(0, h + 0.005, 0), mat("wood_dark"), false, Vector3.ZERO, null, 14)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = h
	_collision(shape, Vector3(0, h * 0.5, 0), Vector3.ZERO, null)


func _crate() -> void:
	var s := size
	add_box(s, Vector3(0, s.y * 0.5, 0), mat("plank_b"))
	var dark := mat("wood_dark")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_box(Vector3(0.07, s.y + 0.01, 0.07), Vector3(sx * (s.x * 0.5 - 0.03), s.y * 0.5, sz * (s.z * 0.5 - 0.03)), dark, false)
	for y in [0.05, s.y - 0.05]:
		add_box(Vector3(s.x + 0.02, 0.07, s.z + 0.02), Vector3(0, y, 0), dark, false)
	add_box(Vector3(0.06, s.y * 1.25, s.z * 0.02 + 0.02), Vector3(0, s.y * 0.5, s.z * 0.5), dark, false, Vector3(0, 0, 45))


func _shelf() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	var dark := mat("wood_dark")
	add_box(Vector3(w, h, 0.03), Vector3(0, h * 0.5, -d * 0.5 + 0.015), mat("wood"), false)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.05, h, d), Vector3(sx * (w * 0.5 - 0.025), h * 0.5, 0), dark, false)
	var rng := make_rng(7)
	for i in shelf_count:
		var y := 0.08 + i * (h - 0.12) / shelf_count
		add_box(Vector3(w - 0.1, 0.04, d - 0.04), Vector3(0, y, 0), mat("plank_a"), false)
		if shelf_items:
			_fill_shelf(rng, y + 0.02, w - 0.16, d, (h - 0.12) / shelf_count - 0.06)
	add_box(Vector3(w, 0.05, d), Vector3(0, h - 0.025, 0), dark, false)
	add_collision_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0))


func _fill_shelf(rng: RandomNumberGenerator, y: float, width: float, depth: float, space: float) -> void:
	var cloth := ["cloth_red", "cloth_blue", "cloth_green", "parchment"]
	var x := -width * 0.5
	while x < width * 0.5 - 0.06:
		var roll := rng.randf()
		if roll < 0.55:
			# A book.
			var t := rng.randf_range(0.04, 0.07)
			var bh := minf(rng.randf_range(0.18, 0.28), space)
			add_box(Vector3(t, bh, depth * 0.65), Vector3(x + t * 0.5, y + bh * 0.5, 0.02), mat(cloth[rng.randi() % cloth.size()]), false)
			x += t + 0.005
		elif roll < 0.75:
			# A bottle (some glow faintly).
			var r := 0.035
			add_cylinder(r, 0.16, Vector3(x + r, y + 0.08, 0.03), mat("glow_warm" if rng.randf() < 0.3 else "glass"), false)
			x += r * 2.0 + 0.03
		elif roll < 0.88:
			# A jar.
			add_cylinder(0.05, 0.1, Vector3(x + 0.05, y + 0.05, 0.03), mat("straw"), false)
			x += 0.13
		else:
			x += rng.randf_range(0.06, 0.15)  # Gap.
