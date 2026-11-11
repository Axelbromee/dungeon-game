class_name HeldItemView
extends Node3D
## First-person hand (child of the camera, lower right of the screen).
## Shows the selected hotbar item and adds look sway, walk bob and a short
## raise animation when switching items. Per-item pose comes from the
## InventoryItem "Held In Hand" settings.

@export_group("Look Sway")
## Metres of lag per pixel of mouse movement.
@export var look_sway_amount: float = 0.0006
@export var look_sway_max: float = 0.04
## Roll (degrees) at maximum sideways sway.
@export var look_tilt_degrees: float = 5.0
@export var sway_smoothing: float = 10.0

@export_group("Walk Bob")
@export var bob_frequency: float = 9.0
@export var bob_horizontal: float = 0.012
@export var bob_vertical: float = 0.01
## Movement speed that gives full-strength bob.
@export var bob_reference_speed: float = 5.0
@export var bob_smoothing: float = 8.0

@export_group("Switch")
## How far the new item starts below its resting spot.
@export var switch_drop: float = 0.18
## How fast it rises into place (1 / seconds).
@export var switch_speed: float = 7.0

var current_item: InventoryItem = null

var _visual: Node3D = null
var _look_input: Vector2 = Vector2.ZERO
var _sway: Vector2 = Vector2.ZERO
var _bob_t: float = 0.0
var _bob_strength: float = 0.0
var _raise: float = 0.0

@onready var _sway_node: Node3D = $Sway
@onready var _item_root: Node3D = $Sway/ItemRoot
@onready var _body: CharacterBody3D = owner as CharacterBody3D


## Show `item` in the hand (null = empty hand). Same item = no change.
func set_item(item: InventoryItem) -> void:
	if item == current_item or (item != null and item.is_same_item(current_item)):
		return
	current_item = item
	if _visual != null:
		_visual.queue_free()
		_visual = null
	if item == null:
		return
	_visual = _build_visual(item)
	if _visual == null:
		return
	_item_root.add_child(_visual)
	_item_root.position = item.held_offset
	_item_root.rotation_degrees = item.held_rotation_degrees
	_item_root.scale = Vector3.ONE * item.held_scale
	_raise = 1.0


## Where held spells charge from (a "CastPoint" node in the held model), or null.
func get_cast_point() -> Node3D:
	if _visual == null:
		return null
	return _visual.find_child("CastPoint", true, false) as Node3D


## Fed by the player's mouse-look so the item lags behind camera turns.
func add_look_input(relative: Vector2) -> void:
	_look_input += relative


func _process(delta: float) -> void:
	# Look sway: offset opposite to the mouse motion, eased back to rest.
	var target := (Vector2(-_look_input.x, _look_input.y) * look_sway_amount).limit_length(look_sway_max)
	_look_input = Vector2.ZERO
	_sway = _sway.lerp(target, 1.0 - exp(-sway_smoothing * delta))

	# Walk bob: figure-eight while moving on the ground.
	var speed := 0.0
	var grounded := true
	if _body:
		speed = Vector2(_body.velocity.x, _body.velocity.z).length()
		grounded = _body.is_on_floor()
	var speed_ratio := clampf(speed / maxf(bob_reference_speed, 0.01), 0.0, 1.6)
	var target_strength := speed_ratio if grounded else 0.0
	_bob_strength = lerpf(_bob_strength, target_strength, 1.0 - exp(-bob_smoothing * delta))
	_bob_t += delta * bob_frequency * maxf(speed_ratio, 0.3)
	var bob := Vector3(sin(_bob_t) * bob_horizontal, sin(_bob_t * 2.0) * bob_vertical, 0.0) * _bob_strength

	# Switch: new item rises from below.
	_raise = move_toward(_raise, 0.0, switch_speed * delta)
	var raise := Vector3.DOWN * switch_drop * _raise * _raise

	_sway_node.position = Vector3(_sway.x, _sway.y, 0.0) + bob + raise
	var tilt := (_sway.x / maxf(look_sway_max, 0.001)) * deg_to_rad(look_tilt_degrees)
	_sway_node.rotation = Vector3(_sway.y * 2.0, -_sway.x * 2.0, tilt)


## Custom held scene, or the world pickup's meshes without physics.
func _build_visual(item: InventoryItem) -> Node3D:
	if item.held_scene:
		return ItemVisuals.build(item.held_scene, true)
	return ItemVisuals.build(item.world_scene)
