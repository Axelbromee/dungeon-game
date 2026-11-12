class_name FireballExplosion
extends Node3D
## One-shot fire burst + light flash. Set `charge_ratio` before adding to the
## tree; frees itself once every emitter has finished.

@export_group("Scaling")
## Burst size multiplier for an uncharged fireball.
@export var min_scale: float = 1.0
## Burst size multiplier for a fully charged fireball.
@export var max_scale: float = 1.8
## Particle count multiplier for a fully charged fireball.
@export var max_amount_multiplier: float = 1.8

@export_group("Blast")
## Push radius when the fireball doesn't supply a splash radius.
@export var min_blast_radius: float = 1.5
@export var max_blast_radius: float = 4.0
## Nodes in this group never hurt each other (slime fireballs vs. slimes).
@export var friendly_group: StringName = &"enemies"
## Outward impulse at the blast centre (falls off linearly to 0 at the edge).
@export var min_blast_impulse: float = 3.0
@export var max_blast_impulse: float = 20.0
@export_flags_3d_physics var blast_mask: int = 1

@export_group("Flash")
@export var flash_energy: float = 8.0
@export var flash_duration: float = 0.35

var charge_ratio: float = 0.0
## Body the blast never pushes or damages (the fireball's caster).
var ignore: Node = null
## Already took the fireball's direct damage, so gets no splash damage.
var direct_target: Node = null
## Set by the fireball. 0 radius = use min/max_blast_radius, push only.
var splash_radius: float = 0.0
var splash_damage: float = 0.0
## Damage multiplier at the edge of the radius.
var splash_edge_factor: float = 0.25

var _emitters_running: int = 0
var _caster_is_friendly: bool = false

@onready var _flash: OmniLight3D = $Flash
@onready var _emitters: Array[GPUParticles3D] = [$Burst, $Embers]


func _ready() -> void:
	# Read now: the caster may be gone by the time the deferred blast runs.
	_caster_is_friendly = friendly_group != &"" and ignore != null \
		and is_instance_valid(ignore) and ignore.is_in_group(friendly_group)
	var s := lerpf(min_scale, max_scale, charge_ratio)
	var amount_mult := lerpf(1.0, max_amount_multiplier, charge_ratio)

	for emitter in _emitters:
		var mat := (emitter.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		mat.emission_sphere_radius *= s
		mat.initial_velocity_min *= s
		mat.initial_velocity_max *= s
		mat.scale_min *= s
		mat.scale_max *= s
		emitter.process_material = mat
		emitter.amount = roundi(emitter.amount * amount_mult)
		emitter.one_shot = true
		emitter.finished.connect(_on_emitter_finished)
		_emitters_running += 1
		emitter.restart()

	_flash.omni_range *= s
	_flash.light_energy = flash_energy * s
	var tween := create_tween()
	tween.tween_property(_flash, "light_energy", 0.0, flash_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Deferred: the spawner sets our position after add_child, and we may have
	# been spawned from inside a physics callback where queries are locked.
	_apply_blast.call_deferred()


func _apply_blast() -> void:
	var radius := splash_radius if splash_radius > 0.0 else lerpf(min_blast_radius, max_blast_radius, charge_ratio)
	var impulse := lerpf(min_blast_impulse, max_blast_impulse, charge_ratio)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = blast_mask

	var handled := {}  # A body with several shapes is reported once per shape.
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider := result.collider as Node3D
		if collider == null or not is_instance_valid(collider) or collider == ignore:
			continue
		if handled.has(collider) or _is_friendly(collider):
			continue
		handled[collider] = true
		var offset := collider.global_position - global_position
		var edge := clampf(_distance_to(collider) / radius, 0.0, 1.0)
		var falloff := 1.0 - edge

		# Splash damage first, so an enemy's stagger can accept this push.
		if splash_damage > 0.0 and collider != direct_target and collider.has_method("take_damage"):
			collider.call("take_damage", splash_damage * lerpf(1.0, splash_edge_factor, edge))
		# Slight upward bias so props hop instead of just sliding.
		var dir := (offset.normalized() + Vector3.UP * 0.5).normalized()
		var body := collider as RigidBody3D
		if body:
			if not body.freeze:
				body.apply_central_impulse(dir * impulse * falloff)
		elif collider.has_method("apply_knockback"):
			collider.call("apply_knockback", dir * impulse * falloff)


## Distance to a body treated as a 1.6 m tall vertical segment from its
## origin, so a blast at chest height counts as "at the centre" for a
## character whose origin is at its feet.
func _distance_to(node: Node3D) -> float:
	var base := node.global_position
	var closest := Vector3(base.x, clampf(global_position.y, base.y, base.y + 1.6), base.z)
	return global_position.distance_to(closest)


func _is_friendly(node: Node) -> bool:
	return _caster_is_friendly and node.is_in_group(friendly_group)


func _on_emitter_finished() -> void:
	_emitters_running -= 1
	if _emitters_running <= 0:
		queue_free()
