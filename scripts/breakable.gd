class_name Breakable
extends RigidBody3D
## Physics prop that takes fireball damage, breaks at 0 health and respawns
## at its starting spot so the test room never runs out of targets.

@export var max_health: float = 30.0
## Seconds before a broken prop reappears. 0 = never.
@export var respawn_time: float = 5.0
## Props that fall below this height are reset.
@export var kill_height: float = -20.0

var health: float

var _spawn_transform: Transform3D
var _layer: int
var _mask: int
var _broken: bool = false
var _reset_pending: bool = false


func _ready() -> void:
	health = max_health
	_spawn_transform = global_transform
	_layer = collision_layer
	_mask = collision_mask


func take_damage(amount: float) -> void:
	if _broken:
		return
	health -= amount
	HitFlash.flash(self)
	if health <= 0.0:
		_break()


func _physics_process(_delta: float) -> void:
	if not _broken and global_position.y < kill_height:
		_respawn()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		_reset_pending = false
		state.transform = _spawn_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO


func _break() -> void:
	_broken = true
	visible = false
	# Deferred: we may be inside a physics callback (fireball hit).
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	_broken = false
	health = max_health
	collision_layer = _layer
	collision_mask = _mask
	freeze = false
	visible = true
	_reset_pending = true
	sleeping = false
