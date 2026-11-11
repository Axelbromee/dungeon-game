@tool
class_name KitDoor
extends KitPiece
## Plank door with iron bands that swings open / closed with E. Sized for a
## KitWall doorway; put it at the doorway's origin. The leaf is its own body
## on the interactable layer so the player can target it.

@export var width: float = 1.15
@export var height: float = 2.15
@export var thickness: float = 0.07
## Degrees; positive swings toward -Z (away from the front).
@export var open_angle: float = 100.0
@export var open_time: float = 0.45
@export var hinge_on_left: bool = true
@export var start_open: bool = false
@export_range(3, 9) var planks: int = 5

var is_open: bool = false

var _pivot: Node3D
var _leaf: StaticBody3D
var _tween: Tween


func _build() -> void:
	var side := -1.0 if hinge_on_left else 1.0
	_pivot = Node3D.new()
	_pivot.position = Vector3(side * width * 0.5, 0, 0)
	add_generated(_pivot)
	_leaf = StaticBody3D.new()
	_leaf.collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	_pivot.add_child(_leaf)

	# Leaf geometry, measured from the hinge.
	var dir := -side
	var plank_w := width / planks
	var mats := ["plank_a", "plank_b", "plank_c"]
	for i in planks:
		add_box(Vector3(plank_w - 0.01, height, thickness), Vector3(dir * (i + 0.5) * plank_w, height * 0.5, 0), mat(mats[i % 3]), false, Vector3.ZERO, _leaf)
	add_collision_box(Vector3(width, height, thickness), Vector3(dir * width * 0.5, height * 0.5, 0), Vector3.ZERO, _leaf)
	var iron := mat("iron")
	for y in [0.35, height - 0.35]:
		add_box(Vector3(width * 0.92, 0.06, thickness + 0.02), Vector3(dir * width * 0.48, y, 0), iron, false, Vector3.ZERO, _leaf)
	# Ring handles on both sides + keyhole plate.
	for face in [1.0, -1.0]:
		add_cylinder(0.05, 0.015, Vector3(dir * width * 0.85, height * 0.47, face * (thickness * 0.5 + 0.02)), mat("brass"), false, Vector3(90, 0, 0), _leaf, 12)
	add_box(Vector3(0.06, 0.12, thickness + 0.03), Vector3(dir * width * 0.85, height * 0.43, 0), iron, false, Vector3.ZERO, _leaf)

	is_open = start_open
	_apply_angle(false)


func get_interaction_text() -> String:
	return "Close door" if is_open else "Open door"


func interact(_player: Player) -> void:
	is_open = not is_open
	_apply_angle(true)


func _apply_angle(animate: bool) -> void:
	var side := -1.0 if hinge_on_left else 1.0
	var target := -side * open_angle if is_open else 0.0
	if _tween:
		_tween.kill()
	if not animate or not is_inside_tree():
		_pivot.rotation_degrees.y = target
		return
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation_degrees:y", target, open_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
