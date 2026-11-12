@tool
class_name KitDoor
extends KitPiece
## Door that swings open / closed with E: the KayKit doorway's own leaf at
## its real size, so it fits a KitWall doorway exactly. Put it at the
## doorway's origin. The leaf is its own body on the interactable layer so
## the player can target it.

## Not used: the leaf has the KayKit doorway's size (kept for old scenes).
@export var width: float = 2.3
## Not used: the leaf has the KayKit doorway's size (kept for old scenes).
@export var height: float = 2.87
## Not used: the leaf has the KayKit doorway's size (kept for old scenes).
@export var thickness: float = 0.78
## Degrees; positive swings toward -Z (away from the front).
@export var open_angle: float = 100.0
@export var open_time: float = 0.45
@export var hinge_on_left: bool = true
@export var start_open: bool = false
## A locked door stays shut; E only shows `locked_text`.
@export var locked: bool = false
@export var locked_text: String = "Locked"
## Not used by the KayKit leaf (kept so existing scenes load unchanged).
@export_range(3, 9) var planks: int = 5

## The KayKit leaf: its size and how far its hinge sits from the middle.
const LEAF_SIZE := Vector3(2.0, 2.75, 0.78)
const HINGE_X := 0.82
const MODEL := "wall_doorway"
const PART := "wall_doorway_door"

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
	var hinge := KitPiece.model_part_xform(kk(MODEL), PART).origin
	add_model_xform(kk(MODEL), Transform3D(turn, turn * -hinge), _leaf, PackedStringArray([PART]))
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
