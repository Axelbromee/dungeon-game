class_name Fireball
extends Area3D
## Chargeable fireball. While charging it sits on the caster's muzzle and is
## inert; after launch() it flies a manual ballistic arc. Bigger charge =
## bigger, slower, heavier (more drop).

signal exploded(at: Vector3, charge_ratio: float)

@export_group("Size")
@export var min_scale: float = 1.0
@export var max_scale: float = 3.0

@export_group("Ballistics")
## Launch speed of a FULLY charged fireball (heavy = slow).
@export var min_speed: float = 12.0
## Launch speed of an UNCHARGED fireball (light = fast).
@export var max_speed: float = 30.0
## Downward acceleration of an UNCHARGED fireball.
@export var min_gravity: float = 2.0
## Downward acceleration of a FULLY charged fireball.
@export var max_gravity: float = 14.0
@export var max_lifetime: float = 6.0

@export_group("Damage")
@export var min_damage: float = 10.0
@export var max_damage: float = 50.0
## Impulse applied to a directly hit RigidBody3D along the flight direction.
@export var min_knockback: float = 4.0
@export var max_knockback: float = 30.0

@export_group("Splash")
## Explosion damage radius for an uncharged / fully charged fireball.
@export var min_splash_radius: float = 1.5
@export var max_splash_radius: float = 4.0
## Splash damage at the centre of the explosion (uncharged / full charge).
## The directly hit target only takes the direct damage, not splash on top.
@export var min_splash_damage: float = 5.0
@export var max_splash_damage: float = 30.0
## Damage multiplier at the edge of the radius (1 = no falloff).
@export_range(0.0, 1.0) var splash_edge_factor: float = 0.25

@export_group("Effects")
@export var explosion_scene: PackedScene
## Light brightness multiplier at full charge (1.0 at no charge).
@export var max_light_energy_multiplier: float = 2.0
@export_range(0.0, 1.0) var light_flicker: float = 0.15

var charge_ratio: float = 0.0
var caster: CollisionObject3D = null
## Scales direct and splash damage (the player's Magic stat sets this).
var damage_multiplier: float = 1.0
var is_launched: bool = false

var _velocity: Vector3 = Vector3.ZERO
var _gravity: float = 0.0
var _age: float = 0.0
var _exploded: bool = false
var _sphere: SphereShape3D
var _trail_material: ParticleProcessMaterial
var _base_radius: float
var _base_light_range: float
var _base_light_energy: float
var _base_trail_radius: float
var _base_trail_scale_min: float
var _base_trail_scale_max: float

@onready var _shape_node: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _trail: GPUParticles3D = $Trail
@onready var _light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	# Per-instance copies so resizing one fireball doesn't resize them all.
	_sphere = (_shape_node.shape as SphereShape3D).duplicate()
	_shape_node.shape = _sphere
	_trail_material = (_trail.process_material as ParticleProcessMaterial).duplicate()
	_trail.process_material = _trail_material

	_base_radius = _sphere.radius
	_base_light_range = _light.omni_range
	_base_light_energy = _light.light_energy
	_base_trail_radius = _trail_material.emission_sphere_radius
	_base_trail_scale_min = _trail_material.scale_min
	_base_trail_scale_max = _trail_material.scale_max

	monitoring = false  # Inert while held on the muzzle.
	body_entered.connect(_on_hit_node)
	area_entered.connect(_on_hit_node)
	set_physics_process(false)
	set_charge(0.0)


## 0.0 = uncharged, 1.0 = fully charged. Resizes visuals, collision, trail, light.
func set_charge(ratio: float) -> void:
	charge_ratio = clampf(ratio, 0.0, 1.0)
	var s := lerpf(min_scale, max_scale, charge_ratio)
	_visual.scale = Vector3.ONE * s
	_sphere.radius = _base_radius * s
	_light.omni_range = _base_light_range * s
	_trail_material.emission_sphere_radius = _base_trail_radius * s
	_trail_material.scale_min = _base_trail_scale_min * s
	_trail_material.scale_max = _base_trail_scale_max * s


## Current collision radius (grows with charge).
func get_radius() -> float:
	return _sphere.radius if _sphere else 0.15


func launch(direction: Vector3, from_caster: CollisionObject3D) -> void:
	caster = from_caster
	_velocity = direction.normalized() * lerpf(max_speed, min_speed, charge_ratio)
	_gravity = lerpf(min_gravity, max_gravity, charge_ratio)
	monitoring = true
	is_launched = true
	add_to_group("fireballs")  # Lets enemies see incoming shots (dodging).
	set_physics_process(true)


func get_flight_velocity() -> Vector3:
	return _velocity


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var flicker := 1.0 + light_flicker * sin(t * 23.0) * sin(t * 17.0 + 1.3)
	var charge_mult := lerpf(1.0, max_light_energy_multiplier, charge_ratio)
	_light.light_energy = _base_light_energy * charge_mult * flicker


## True if the caster still exists and is the player.
func is_from_player() -> bool:
	return is_instance_valid(caster) and caster is Player


## The caster can die while its fireball is still flying (a slime killed
## mid-shot). Drop the reference so nothing touches a freed object.
## Note: a freed object can compare equal to null, so only
## is_instance_valid() is a reliable check here.
func _forget_dead_caster() -> void:
	if not is_instance_valid(caster):
		caster = null


func _physics_process(delta: float) -> void:
	_forget_dead_caster()
	_age += delta
	if _age >= max_lifetime:
		_detach_trail()
		queue_free()
		return

	_velocity += Vector3.DOWN * _gravity * delta
	var from := global_position
	var to := from + _velocity * delta

	# Sweep the path so fast shots can't tunnel through thin geometry.
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_areas = true
	if caster != null:
		query.exclude = [caster.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_explode(hit.position, hit.collider)
		return

	global_position = to


func _on_hit_node(node: Node3D) -> void:
	_forget_dead_caster()
	if caster != null and node == caster:
		return
	_explode(global_position, node)


func _explode(at: Vector3, target: Object) -> void:
	if _exploded:
		return
	_exploded = true
	set_physics_process(false)
	_forget_dead_caster()
	if not is_instance_valid(target):
		target = null

	if target and target.has_method("take_damage"):
		target.call("take_damage", lerpf(min_damage, max_damage, charge_ratio) * damage_multiplier)
	var push := _velocity.normalized() * lerpf(min_knockback, max_knockback, charge_ratio)
	if target is RigidBody3D:
		var body := target as RigidBody3D
		body.apply_impulse(push, at - body.global_position)
	elif target and target.has_method("apply_knockback"):
		target.call("apply_knockback", push)

	if explosion_scene:
		var fx := explosion_scene.instantiate() as FireballExplosion
		fx.charge_ratio = charge_ratio
		fx.ignore = caster
		fx.direct_target = target as Node
		fx.splash_radius = lerpf(min_splash_radius, max_splash_radius, charge_ratio)
		fx.splash_damage = lerpf(min_splash_damage, max_splash_damage, charge_ratio) * damage_multiplier
		fx.splash_edge_factor = splash_edge_factor
		get_tree().current_scene.add_child(fx)
		fx.global_position = at

	_detach_trail()
	exploded.emit(at, charge_ratio)
	queue_free()


## Leave the trail behind so its live particles fade out instead of vanishing.
func _detach_trail() -> void:
	if _trail.get_parent() != self:
		return
	_trail.reparent(get_tree().current_scene)
	_trail.emitting = false
	get_tree().create_timer(_trail.lifetime + 0.1).timeout.connect(_trail.queue_free)
