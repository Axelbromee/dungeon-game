@tool
class_name KitDoor
extends KitPiece
## Door that swings open / closed with E: the Medieval Village door leaf
## (Door_1_Round) at its real size, so it fits a KitWall doorway exactly. Put it at the
## doorway's origin. The leaf is its own body on the interactable layer so
## the player can target it.

## Not used: the leaf has the model's size (kept for old scenes).
@export var width: float = 2.3
## Not used: the leaf has the model's size (kept for old scenes).
@export var height: float = 2.87
## Not used: the leaf has the model's size (kept for old scenes).
@export var thickness: float = 0.78
## Degrees; positive swings toward -Z (away from the front).
@export var open_angle: float = 100.0
@export var open_time: float = 0.45
@export var hinge_on_left: bool = true
@export var start_open: bool = false
## A locked door stays shut; E only shows `locked_text`.
@export var locked: bool = false
@export var locked_text: String = "Locked"
## Not used by the model leaf (kept so existing scenes load unchanged).
@export_range(3, 9) var planks: int = 5

## The leaf (Door_1_Round: 1.12 x 2.32 x 0.12 m, hinge at the model's
## origin, leaf toward +X): its size and how far its hinge sits from the middle.
const LEAF_SIZE := Vector3(1.12, 2.32, 0.12)
const HINGE_X := 0.56
const MODEL := "Door_1_Round"

var is_open: bool = false

var _pivot: Node3D
var _leaf: StaticBody3D
var _tween: Tween


func _build() -> void:
	var side := -1.0 if hinge_on_left else 1.0
	_pivot = Node3D.new()
	_pivot.position = Vector3(side * HINGE_X, 0, 0)
	add_generated(_pivot)
	_leaf = StaticBody3D.new()
	_leaf.collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	_pivot.add_child(_leaf)

	# Leaf geometry, measured from the hinge. A right-hinged door is the
	# same leaf turned around.
	var dir := -side
	var turn := Basis(Vector3.UP, 0.0 if hinge_on_left else PI)
	add_model_xform(mv(MODEL), Transform3D(turn, Vector3.ZERO), _leaf)
	add_collision_box(LEAF_SIZE, Vector3(dir * HINGE_X, LEAF_SIZE.y * 0.5, 0), Vector3.ZERO, _leaf)

	is_open = start_open
	_apply_angle(false)


func get_interaction_text() -> String:
	if locked:
		return locked_text
	return "Close door" if is_open else "Open door"


func interact(_player: Player) -> void:
	if locked:
		return
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
