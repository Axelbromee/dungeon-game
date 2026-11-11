@tool
class_name KitWall
extends KitPiece
## Wall segment, one grid cell wide: stone base, plaster above, dark timber
## frame. Plain, with a window, or with a doorway (put a KitDoor in it).
## Origin at floor level in the middle of the wall; the wall runs along X,
## its thickness along Z.

enum Style { PLAIN, WINDOW, DOORWAY }

@export var style: Style = Style.PLAIN
@export var width: float = 2.0
@export var height: float = 3.0
@export var thickness: float = 0.25
## Height of the stone base.
@export var plinth_height: float = 0.7
@export var timber_frame: bool = true
@export_group("Window")
@export var window_width: float = 0.9
@export var window_height: float = 1.0
@export var window_sill: float = 1.1
@export_group("Doorway")
@export var door_width: float = 1.2
@export var door_height: float = 2.2

const TIMBER := 0.14


func _build() -> void:
	var half := width * 0.5
	var hole := Rect2()
	match style:
		Style.WINDOW:
			hole = Rect2(-window_width * 0.5, window_sill, window_width, window_height)
		Style.DOORWAY:
			hole = Rect2(-door_width * 0.5, 0.0, door_width, door_height)

	if hole.size == Vector2.ZERO:
		_slab(-half, half, 0.0, height)
	else:
		var x0 := hole.position.x
		var x1 := hole.end.x
		var y0 := hole.position.y
		var y1 := hole.end.y
		_slab(-half, x0, 0.0, height)
		_slab(x1, half, 0.0, height)
		_slab(x0, x1, 0.0, y0)
		_slab(x0, x1, y1, height)
		_hole_frame(hole)
		if style == Style.WINDOW:
			_window_panes(hole)

	if timber_frame:
		var depth := thickness + 0.04
		var wood := mat("wood_dark")
		add_box(Vector3(TIMBER, height - plinth_height, depth), Vector3(-half + TIMBER * 0.5, (height + plinth_height) * 0.5, 0), wood, false)
		add_box(Vector3(TIMBER, height - plinth_height, depth), Vector3(half - TIMBER * 0.5, (height + plinth_height) * 0.5, 0), wood, false)
		add_box(Vector3(width, 0.16, depth), Vector3(0, height - 0.08, 0), wood, false)
		add_box(Vector3(width, 0.08, depth), Vector3(0, plinth_height + 0.04, 0), wood, false)


## Wall material between xa..xb, ya..yb: stone below the plinth line,
## plaster above.
func _slab(xa: float, xb: float, ya: float, yb: float) -> void:
	if xb - xa <= 0.001 or yb - ya <= 0.001:
		return
	var cx := (xa + xb) * 0.5
	var split := clampf(plinth_height, ya, yb)
	if split > ya:
		add_box(Vector3(xb - xa, split - ya, thickness + 0.04), Vector3(cx, (ya + split) * 0.5, 0), mat("stone_wall"))
	if yb > split:
		add_box(Vector3(xb - xa, yb - split, thickness), Vector3(cx, (split + yb) * 0.5, 0), mat("plaster"))


func _hole_frame(hole: Rect2) -> void:
	var wood := mat("wood")
	var depth := thickness + 0.06
	var board := 0.08
	var x0 := hole.position.x
	var x1 := hole.end.x
	var y0 := hole.position.y
	var y1 := hole.end.y
	add_box(Vector3(board, y1 - y0, depth), Vector3(x0 + board * 0.5, (y0 + y1) * 0.5, 0), wood, false)
	add_box(Vector3(board, y1 - y0, depth), Vector3(x1 - board * 0.5, (y0 + y1) * 0.5, 0), wood, false)
	add_box(Vector3(hole.size.x + board * 2.0, board * 1.5, depth), Vector3((x0 + x1) * 0.5, y1 + board * 0.5, 0), mat("wood_dark"), false)
	if y0 > 0.01:
		add_box(Vector3(hole.size.x + board * 2.0, board, depth + 0.06), Vector3((x0 + x1) * 0.5, y0 - board * 0.5, 0), wood, false)


func _window_panes(hole: Rect2) -> void:
	var center := Vector3((hole.position.x + hole.end.x) * 0.5, (hole.position.y + hole.end.y) * 0.5, 0)
	# Glass blocks the hole; iron bars make a cross.
	add_box(Vector3(hole.size.x, hole.size.y, 0.02), center, mat("glass"))
	var iron := mat("iron")
	add_box(Vector3(0.03, hole.size.y, 0.04), center, iron, false)
	add_box(Vector3(hole.size.x, 0.03, 0.04), center, iron, false)
