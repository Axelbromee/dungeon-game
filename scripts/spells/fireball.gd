class_name Fireball
extends Area3D
## Fireball. Every one is the same: one size, speed, drop, damage and
## explosion (the slime sets its own numbers on the fireballs it shoots).
## While being cast it sits on the caster's muzzle and is inert; after
## launch() it flies a manual ballistic arc.
## Casting look (player casts, see ChargedProjectileCaster): at first no
## fireball, only embers spiralling inward to a point above the book, faster
## and denser as the cast goes on (gather()); at the minimum charge time
## they collapse into the fireball, which forms in a quick, smooth burst
## (form()) and then just flickers until it's thrown. Cancelled while
## gathering, the embers scatter and fade (scatter()); cancelled once formed,
## the fireball shrinks and fizzles out (fizzle()).

signal exploded(at: Vector3)

@export_group("Size")
## Size of the fireball (1 = the scene's base size). Its light grows with it.
@export var size_scale: float = 2.0

@export_group("Ballistics")
## Launch speed.
@export var speed: float = 21.0
## Downward acceleration in flight.
@export var fall_acceleration: float = 8.0
@export var max_lifetime: float = 6.0

@export_group("Damage")
@export var damage: float = 30.0
## Impulse applied to a directly hit RigidBody3D along the flight direction.
@export var knockback: float = 17.0

@export_group("Splash")
## Explosion damage radius.
@export var splash_radius: float = 2.75
## Splash damage at the centre of the explosion. The directly hit target only
## takes the direct damage, not splash on top.
@export var splash_damage: float = 17.5
## Damage multiplier at the edge of the radius (1 = no falloff).
@export_range(0.0, 1.0) var splash_edge_factor: float = 0.25
## Explosion burst size / particle count, and its outward push at the centre.
@export var explosion_scale: float = 1.4
@export var explosion_impulse: float = 11.5

@export_group("Casting Look")
## Embers start this far around the gathering point.
@export var gather_radius: float = 0.35
## How fast the embers spiral in at the start of the cast and just before
## the fireball forms (1 = one ember lifetime per trip).
@export var gather_speed_start: float = 0.7
@export var gather_speed_end: float = 2.2
## How many embers at the start of the cast (share of the most).
@export_range(0.0, 1.0) var gather_density_start: float = 0.25
## Seconds for the fireball to form when the cast becomes ready.
@export var form_time: float = 0.18
## Cancelled while gathering: seconds for the embers to scatter and fade.
@export var scatter_time: float = 0.3
## Cancelled once formed: seconds to shrink and fizzle out.
@export var fizzle_time: float = 0.22

@export_group("Effects")
@export var explosion_scene: PackedScene
@export_range(0.0, 1.0) var light_flicker: float = 0.15

var caster: CollisionObject3D = null
## Scales direct and splash damage (the player's Magic stat sets this).
var damage_multiplier: float = 1.0
var is_launched: bool = false

var _velocity: Vector3 = Vector3.ZERO
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
## How much of the fireball is there (0 = only gathering embers, 1 = formed).
## A fireball that never gather()s (the slimes') is formed from the start.
var _form: float = 1.0
var _fizzle: float = 1.0
var _ending: bool = false
var _core_material: StandardMaterial3D
var _shell_material: ShaderMaterial
var _gather_material: ShaderMaterial
var _base_core_emission: float
var _base_shell_intensity: float

@onready var _shape_node: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _trail: GPUParticles3D = $Trail
@onready var _light: OmniLight3D = $OmniLight3D
@onready var _core: MeshInstance3D = $Visual/Core
@onready var _shell: MeshInstance3D = $Visual/Shell
@onready var _gather: GPUParticles3D = $Gather


func _ready() -> void:
	# Per-instance copies so changing one fireball doesn't change them all.
	_sphere = (_shape_node.shape as SphereShape3D).duplicate()
	_shape_node.shape = _sphere
	_trail_material = (_trail.process_material as ParticleProcessMaterial).duplicate()
	_trail.process_material = _trail_material
	_core_material = (_core.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_core.material_override = _core_material
	_shell_material = (_shell.mesh.surface_get_material(0) as ShaderMaterial).duplicate()
	_shell.material_override = _shell_material
	_gather_material = (_gather.process_material as ShaderMaterial).duplicate()
	_gather.process_material = _gather_material
	_base_core_emission = _core_material.emission_energy_multiplier
	_base_shell_intensity = float(_shell_material.get_shader_parameter("intensity"))

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
	_apply_visuals()


## Start of a cast: no fireball yet, only embers spiralling inward.
func gather() -> void:
	_form = 0.0
	_trail.emitting = false
	_gather_material.set_shader_parameter("start_radius", gather_radius)
	_gather_material.set_shader_parameter("scatter", 0.0)
	set_gather_progress(0.0)
	_gather.emitting = true
	_apply_visuals()


## 0 = cast just started, 1 = about to form: the embers spiral in faster and
## denser.
func set_gather_progress(progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	_gather_material.set_shader_parameter("speed", lerpf(gather_speed_start, gather_speed_end, p))
	_gather.amount_ratio = lerpf(gather_density_start, 1.0, p)


## The cast is ready: the embers collapse into the fireball, which forms in
## a quick, smooth burst.
func form() -> void:
	_gather_material.set_shader_parameter("speed", gather_speed_end * 2.0)
	_gather.emitting = false  # The last embers rush in.
	_trail.emitting = true
	var tween := create_tween()
	tween.tween_method(_set_form, 0.0, 1.0, form_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Cancelled while gathering: the embers scatter and fade, then free.
func scatter() -> void:
	if _ending:
		return
	_ending = true
	_gather.emitting = false
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: _gather_material.set_shader_parameter("scatter", value),
		0.0, 1.0, scatter_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


## Cancelled once formed: shrink and fade out quickly, then free.
func fizzle() -> void:
	if _ending:
		return
	_ending = true
	_gather.emitting = false
	_trail.emitting = false
	var tween := create_tween()
	tween.tween_method(_set_fizzle, 1.0, 0.0, fizzle_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## True once the fireball has started forming (it can be thrown).
func is_formed() -> bool:
	return _form > 0.0


func _set_form(value: float) -> void:
	_form = value


func _set_fizzle(value: float) -> void:
	_fizzle = value


## Size and brightness: the fixed size, scaled by forming / fizzling.
func _apply_visuals() -> void:
	var s := size_scale * _form * _fizzle
	_visual.visible = s > 0.001
	_visual.scale = Vector3.ONE * maxf(s, 0.001)
	_sphere.radius = _base_radius * maxf(s, 0.001)
	_light.omni_range = _base_light_range * maxf(s, 0.001)
	_trail_material.emission_sphere_radius = _base_trail_radius * s
	_trail_material.scale_min = _base_trail_scale_min * s
	_trail_material.scale_max = _base_trail_scale_max * s
	var glow := _form * _fizzle
	_core_material.emission_energy_multiplier = _base_core_emission * glow
	_core.transparency = 1.0 - clampf(glow, 0.0, 1.0)
	_shell_material.set_shader_parameter("intensity", _base_shell_intensity * glow)


## Collision radius (and how far it floats in front of the book).
func get_radius() -> float:
	return _base_radius * size_scale


func launch(direction: Vector3, from_caster: CollisionObject3D) -> void:
	caster = from_caster
	_velocity = direction.normalized() * speed
	_gather.emitting = false
	monitoring = true
	is_launched = true
	add_to_group("fireballs")  # Lets enemies see incoming shots (dodging).
	set_physics_process(true)


func get_flight_velocity() -> Vector3:
	return _velocity


func _process(_delta: float) -> void:
	_apply_visuals()
	var t := Time.get_ticks_msec() * 0.001
	var flicker := 1.0 + light_flicker * sin(t * 23.0) * sin(t * 17.0 + 1.3)
	# Bigger fireballs light more (as charged ones used to).
	var size_mult := 1.0 + (size_scale - 1.0) * 0.5
	_light.light_energy = _base_light_energy * size_mult * flicker * _form * _fizzle


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

	_velocity += Vector3.DOWN * fall_acceleration * delta
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
		target.call("take_damage", damage * damage_multiplier)
	var push := _velocity.normalized() * knockback
	if target is RigidBody3D:
		var body := target as RigidBody3D
		body.apply_impulse(push, at - body.global_position)
	elif target and target.has_method("apply_knockback"):
		target.call("apply_knockback", push)

	if explosion_scene:
		var fx := explosion_scene.instantiate() as FireballExplosion
		fx.size_scale = explosion_scale
		fx.blast_impulse = explosion_impulse
		fx.ignore = caster
		fx.direct_target = target as Node
		fx.splash_radius = splash_radius
		fx.splash_damage = splash_damage * damage_multiplier
		fx.splash_edge_factor = splash_edge_factor
		get_tree().current_scene.add_child(fx)
		fx.global_position = at

	_detach_trail()
	exploded.emit(at)
	queue_free()


## Leave the trail behind so its live particles fade out instead of vanishing.
func _detach_trail() -> void:
	if _trail.get_parent() != self:
		return
	_trail.reparent(get_tree().current_scene)
	_trail.emitting = false
	get_tree().create_timer(_trail.lifetime + 0.1).timeout.connect(_trail.queue_free)
