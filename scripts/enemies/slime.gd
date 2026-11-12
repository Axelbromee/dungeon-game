class_name Slime
extends CharacterBody3D
## Hopping slime enemy.
## States:
##   IDLE         wobbles in place
##   HOP          chases the player in hops (small contact bump on touch)
##   JUMP_ATTACK  squash + shake warning -> rises above the player -> hangs ->
##                slams straight down onto its landing shadow -> splash
##   FIRE_ATTACK  stops, glows as a warning, shoots a small fireball
##   HURT         short flinch + knockback (only from IDLE / HOP, with cooldown)
##   DEAD         flattens, fades, drops loot
## Damage always lands and flashes, but only IDLE / HOP can be interrupted,
## so fireball spam can't stunlock its attacks.

signal died(slime: Slime)

enum State { IDLE, HOP, HURT, DEAD, JUMP_ATTACK, FIRE_ATTACK, DODGE }
enum JumpPhase { WINDUP, RISE, HANG, SLAM, RECOVER }
enum FirePhase { WINDUP, RECOVER }

@export_group("Creature")
## Strength tier, S (strongest) to F. Its magic core drop matches this grade.
@export var grade: InventoryItem.Grade = InventoryItem.Grade.F

@export_group("Health")
@export var max_health: float = 50.0

@export_group("Senses")
## Starts chasing when the player is closer than this.
@export var detect_range: float = 12.0
## Gives up and idles when the player gets farther than this.
@export var lose_range: float = 18.0

@export_group("Hop")
## Seconds spent on the ground between hops.
@export var hop_interval: float = 0.9
## Last part of the ground time spent squashing before take-off.
@export var hop_windup: float = 0.25
@export var hop_speed: float = 3.5
@export var hop_up_velocity: float = 4.5
@export var turn_speed: float = 6.0
@export var gravity_multiplier: float = 1.0
@export var ground_friction: float = 18.0

@export_group("Contact")
@export var contact_damage: float = 8.0
@export var contact_range: float = 1.0
@export var contact_cooldown: float = 1.0
@export var contact_knockback: float = 5.0
@export var contact_knockback_up: float = 2.0

@export_group("Jump Attack")
## Starts a jump attack when the player is closer than this (while hopping).
@export var jump_attack_range: float = 4.0
## Seconds before another jump attack can start.
@export var jump_attack_cooldown: float = 3.0
## Warning: seconds spent squashed and shaking before the leap.
@export var jump_windup_time: float = 0.3
@export var jump_windup_squash: float = -0.45
@export var jump_shake_amount: float = 0.04
@export var jump_shake_speed: float = 45.0
## Peak height of the leap above the take-off point (m). Automatically
## lowered if the ceiling is in the way.
@export var jump_height: float = 5.0
## Gap kept between the top of the slime and the ceiling at the apex.
@export var jump_ceiling_margin: float = 0.3
## Leaps never travel farther than this horizontally.
@export var jump_max_distance: float = 7.0
## Seconds frozen in the air at the top, above the target, before slamming.
@export var jump_hang_time: float = 0.3
## Constant downward speed of the slam (m/s).
@export var jump_slam_speed: float = 22.0
@export var jump_air_stretch: float = 0.08
@export var jump_hang_squash: float = -0.15
@export var jump_slam_stretch: float = 0.5
@export var jump_takeoff_kick: float = 5.0
@export var jump_landing_kick: float = -8.0
## Seconds sitting still after landing before chasing again.
@export var jump_recover_time: float = 0.5
@export_subgroup("Slam Area")
## Area of the slam. The landing shadow grows to exactly this size.
@export var slam_radius: float = 3.0
## Damage at the centre of the slam.
@export var slam_damage: float = 20.0
## Damage multiplier at the edge of the radius.
@export_range(0.0, 1.0) var slam_edge_damage_factor: float = 0.3
## Knockback at the centre (scaled down towards the edge like the damage).
@export var slam_knockback: float = 8.0
@export var slam_knockback_up: float = 4.0
@export_range(0.0, 1.0) var slam_edge_knockback_factor: float = 0.4
## Player within this height of the landing spot can be hit.
@export var slam_max_height_difference: float = 2.0
@export var shockwave_duration: float = 0.35
@export_subgroup("Landing Shadow")
## Shadow radius (m) right after take-off. It grows to slam_radius.
@export var shadow_start_radius: float = 0.4
@export var shadow_start_alpha: float = 0.25
@export var shadow_end_alpha: float = 0.75

@export_group("Fireball Attack")
## Player distance band in which the slime will shoot.
@export var fire_min_range: float = 6.0
@export var fire_max_range: float = 15.0
@export var fire_cooldown: float = 4.0
## Warning: seconds spent glowing before the shot.
@export var fire_windup_time: float = 0.8
## Seconds standing still after the shot.
@export var fire_recover_time: float = 0.5
@export var fireball_scene: PackedScene
## Visual size of the projectile (0 = smallest fireball, 1 = full charge).
@export_range(0.0, 1.0) var fire_charge: float = 0.15
## Direct-hit damage.
@export var fire_damage: float = 12.0
## Explosion area: damage at the centre, falling off to the edge factor.
@export var fire_splash_radius: float = 2.0
@export var fire_splash_damage: float = 10.0
@export_range(0.0, 1.0) var fire_splash_edge_factor: float = 0.3
@export var fire_knockback: float = 4.0
@export var fire_projectile_speed: float = 14.0
@export var fire_projectile_gravity: float = 2.0
## Where the shot leaves the slime: height above its base, distance in front.
@export var fire_muzzle_height: float = 0.6
@export var fire_muzzle_forward: float = 0.65
## Aim point above the player's feet.
@export var fire_aim_height: float = 1.0
@export var fire_glow_color: Color = Color(1.0, 0.45, 0.08)
@export var fire_glow_energy: float = 3.5
@export var fire_windup_swell: float = 0.15
@export var fire_recoil: float = 1.5

@export_group("Hurt")
@export var hurt_duration: float = 0.35
## After being knocked back, further hits only deal damage for this long.
@export var knockback_cooldown: float = 1.2
## Converts a fireball impulse into velocity (acts like 1 / mass).
@export var knockback_scale: float = 0.2
@export var knockback_lift: float = 2.0
@export var flash_color: Color = Color(1.0, 0.95, 0.85)
@export var flash_energy: float = 4.0
@export var flash_duration: float = 0.18
## Seconds the HP label stays visible after a hit.
@export var health_label_time: float = 2.5

@export_group("Squash & Stretch")
@export var squash_stiffness: float = 180.0
@export var squash_damping: float = 10.0
@export var windup_squash: float = -0.3
@export var air_stretch_per_speed: float = 0.06
@export var takeoff_kick: float = 3.0
@export var landing_kick: float = -4.0
@export var hit_kick: float = 5.0
@export var idle_wobble: float = 0.04
@export var idle_wobble_speed: float = 3.0

@export_group("Dodge")
## Chance to hop aside from a player fireball that would pass close by.
## Rolled once per fireball. Only from IDLE / HOP, never mid-attack.
@export_range(0.0, 1.0) var dodge_chance: float = 0.3
@export var dodge_cooldown: float = 2.0
## A fireball counts as a threat if it will pass within this distance...
@export var dodge_threat_radius: float = 1.3
## ...within this many seconds.
@export var dodge_reaction_time: float = 0.6
@export var dodge_speed: float = 6.0
@export var dodge_up_velocity: float = 3.5

@export_group("Death & Loot")
## XP given to the player on death (random in this range).
@export var xp_min: int = 20
@export var xp_max: int = 50
@export var death_duration: float = 0.45
@export_subgroup("Drops")
## Every creature carries a magic core matching its grade.
@export var core_item: InventoryItem
@export_range(0.0, 1.0) var core_chance: float = 1.0
@export var jelly_item: InventoryItem
@export var jelly_min: int = 1
@export var jelly_max: int = 2
## Rare drops, each rolled independently.
@export var crystal_item: InventoryItem
@export_range(0.0, 1.0) var crystal_chance: float = 0.15
@export var royal_jelly_item: InventoryItem
@export_range(0.0, 1.0) var royal_jelly_chance: float = 0.05
@export var royal_crystal_item: InventoryItem
@export_range(0.0, 1.0) var royal_crystal_chance: float = 0.01
@export_subgroup("")
@export var loot_toss_speed: float = 2.5
@export var loot_toss_up: float = 3.0

var state: State = State.IDLE
var health: float = 0.0

var _player: Player
var _state_timer: float = 0.0
var _hop_timer: float = 0.0
var _contact_timer: float = 0.0
var _label_timer: float = 0.0
var _was_on_floor: bool = true
var _squash: float = 0.0
var _squash_velocity: float = 0.0
var _t: float = 0.0
var _body_material: StandardMaterial3D
var _base_emission: Color
var _base_emission_energy: float
var _flash_tween: Tween

var _jump_phase: JumpPhase = JumpPhase.WINDUP
var _jump_cooldown_timer: float = 0.0
var _air_time: float = 0.0
var _jump_total_time: float = 1.0
var _shadow_material: StandardMaterial3D
var _jump_exception: Player = null

var _fire_phase: FirePhase = FirePhase.WINDUP
var _fire_cooldown_timer: float = 0.0

var _dodge_cooldown_timer: float = 0.0
## Fireball instance ids already rolled for, so each shot gets one roll.
var _dodge_rolled: Dictionary = {}

var _knockback_cooldown_timer: float = 0.0
## True during the HURT state caused by a hit, so that hit's knockback lands.
var _knockback_armed: bool = false

var _shockwave_material: StandardMaterial3D
var _shockwave_tween: Tween

@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _health_label: Label3D = $HealthLabel
@onready var _shadow: MeshInstance3D = $LandingShadow
@onready var _splash: GPUParticles3D = $Splash
@onready var _shockwave: MeshInstance3D = $Shockwave


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_shockwave_material = (_shockwave.material_override as StandardMaterial3D).duplicate()
	_shockwave.material_override = _shockwave_material
	_shockwave.visible = false
	_t = randf() * 10.0
	_hop_timer = randf_range(0.2, hop_interval)
	# Own material copies so one slime's flash/glow doesn't affect the others.
	_body_material = (_body_mesh.material_override as StandardMaterial3D).duplicate()
	_body_mesh.material_override = _body_material
	_base_emission = _body_material.emission
	_base_emission_energy = _body_material.emission_energy_multiplier
	_health_label.visible = false
	_shadow_material = (_shadow.material_override as StandardMaterial3D).duplicate()
	_shadow.material_override = _shadow_material
	_shadow.visible = false
	_jump_cooldown_timer = randf_range(0.5, jump_attack_cooldown)
	_fire_cooldown_timer = randf_range(1.0, fire_cooldown)


func _physics_process(delta: float) -> void:
	_t += delta
	_state_timer += delta
	_contact_timer -= delta
	_jump_cooldown_timer -= delta
	_fire_cooldown_timer -= delta
	_knockback_cooldown_timer -= delta
	_dodge_cooldown_timer -= delta
	_update_health_label(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player

	if not is_on_floor():
		velocity += get_gravity() * gravity_multiplier * delta

	var target_squash := 0.0
	match state:
		State.IDLE:
			target_squash = _state_idle(delta)
		State.HOP:
			target_squash = _state_hop(delta)
		State.HURT:
			target_squash = _state_hurt(delta)
		State.JUMP_ATTACK:
			target_squash = _state_jump_attack(delta)
		State.FIRE_ATTACK:
			target_squash = _state_fire_attack(delta)
		State.DODGE:
			target_squash = _state_dodge(delta)
		State.DEAD:
			_apply_friction(delta)
			move_and_slide()
			return  # Death tween owns the visual scale.

	move_and_slide()
	_check_landing()
	_update_squash(delta, target_squash)


# --- States -----------------------------------------------------------------

func _state_idle(delta: float) -> float:
	_apply_friction(delta)
	if _try_dodge():
		return 0.0
	if _can_fire_attack():
		_set_state(State.FIRE_ATTACK)
	elif _player_in_range(detect_range):
		_set_state(State.HOP)
	return sin(_t * idle_wobble_speed) * idle_wobble


func _state_hop(delta: float) -> float:
	if not _player_in_range(lose_range):
		_set_state(State.IDLE)
		return 0.0
	_face(_player.global_position, delta)
	_try_contact()

	if not is_on_floor():
		return clampf(velocity.y * air_stretch_per_speed, -0.25, 0.35)

	_apply_friction(delta)
	if _try_dodge():
		return 0.0
	if _jump_cooldown_timer <= 0.0 and _player_in_range(jump_attack_range):
		_set_state(State.JUMP_ATTACK)
		return jump_windup_squash
	if _can_fire_attack():
		_set_state(State.FIRE_ATTACK)
		return 0.0
	_hop_timer -= delta
	if _hop_timer <= 0.0:
		_hop_toward(_player.global_position)
		return 0.0
	if _hop_timer <= hop_windup:
		return windup_squash
	return sin(_t * idle_wobble_speed) * idle_wobble


func _state_dodge(_delta: float) -> float:
	if _state_timer > 0.1 and is_on_floor():
		_set_state(State.HOP if _player_in_range(lose_range) else State.IDLE)
		return 0.0
	return clampf(velocity.y * air_stretch_per_speed, -0.25, 0.35)


## Looks for a player fireball about to pass close by; on a successful
## dodge_chance roll, hops sideways off its path. Called from IDLE / HOP only
## (on the ground), so attacks are never interrupted.
func _try_dodge() -> bool:
	if _dodge_cooldown_timer > 0.0 or not is_on_floor() or dodge_chance <= 0.0:
		return false
	var center := global_position + Vector3.UP * 0.4
	for node in get_tree().get_nodes_in_group("fireballs"):
		var fireball := node as Fireball
		if fireball == null or not fireball.is_launched or not fireball.is_from_player():
			continue
		var id := fireball.get_instance_id()
		if _dodge_rolled.has(id):
			continue
		var fb_velocity := fireball.get_flight_velocity()
		var speed_sq := fb_velocity.length_squared()
		if speed_sq < 0.01:
			continue
		# Closest approach of the (straight-line) path to our centre.
		var to_us := center - fireball.global_position
		var time_to_closest := to_us.dot(fb_velocity) / speed_sq
		if time_to_closest < 0.0 or time_to_closest > dodge_reaction_time:
			continue
		var miss_offset := to_us - fb_velocity * time_to_closest
		if miss_offset.length() > dodge_threat_radius + fireball.get_radius():
			continue

		_dodge_rolled[id] = true
		_prune_dodge_rolls()
		if randf() >= dodge_chance:
			continue  # Failed the roll: this shot gets no second chance.
		_dodge_from(fb_velocity, miss_offset)
		return true
	return false


func _dodge_from(fb_velocity: Vector3, miss_offset: Vector3) -> void:
	var side := fb_velocity.cross(Vector3.UP)
	side.y = 0.0
	side = side.normalized()
	if side.length() < 0.1:
		side = global_basis.x
	# Hop to the side of the path we're already on (random if dead centre).
	var side_sign := signf(miss_offset.dot(side))
	if side_sign == 0.0:
		side_sign = 1.0 if randf() < 0.5 else -1.0
	velocity = side * side_sign * dodge_speed + Vector3.UP * dodge_up_velocity
	_squash_velocity += takeoff_kick * 1.5
	_dodge_cooldown_timer = dodge_cooldown
	_set_state(State.DODGE)


func _prune_dodge_rolls() -> void:
	for id in _dodge_rolled.keys():
		if not is_instance_id_valid(id):
			_dodge_rolled.erase(id)


func _state_hurt(delta: float) -> float:
	if is_on_floor():
		_apply_friction(delta * 0.3)  # Let the knockback slide a bit.
	if _state_timer >= hurt_duration:
		_set_state(State.HOP if _player_in_range(lose_range) else State.IDLE)
	return 0.0


func _set_state(new_state: State) -> void:
	# Leaving-state cleanup.
	if state == State.JUMP_ATTACK and new_state != State.JUMP_ATTACK:
		_hide_jump_helpers()
	if state == State.FIRE_ATTACK and new_state != State.FIRE_ATTACK:
		_set_glow(0.0)
	if state == State.HURT and new_state != State.HURT:
		_knockback_armed = false

	state = new_state
	_state_timer = 0.0
	match new_state:
		State.HOP:
			_hop_timer = minf(_hop_timer, hop_interval * 0.5)
		State.JUMP_ATTACK:
			_jump_phase = JumpPhase.WINDUP
			_jump_cooldown_timer = jump_attack_cooldown
		State.FIRE_ATTACK:
			_fire_phase = FirePhase.WINDUP
			_fire_cooldown_timer = fire_cooldown


# --- Jump attack ------------------------------------------------------------

func _state_jump_attack(delta: float) -> float:
	match _jump_phase:
		JumpPhase.WINDUP:
			_apply_friction(delta)
			if _player_in_range(lose_range):
				_face(_player.global_position, delta)
			# Shake as a warning.
			var shake := jump_shake_amount
			_visual.position = Vector3(sin(_t * jump_shake_speed) * shake, 0.0, cos(_t * jump_shake_speed * 1.3) * shake)
			if _state_timer >= jump_windup_time:
				if _player_in_range(lose_range):
					_launch_jump_attack(_player.global_position)
				else:
					_set_state(State.IDLE)
			return jump_windup_squash

		JumpPhase.RISE:
			_air_time += delta
			_update_shadow()
			if velocity.y <= 0.0:
				# Reached the top, right above the target: freeze.
				_jump_phase = JumpPhase.HANG
				_state_timer = 0.0
				velocity = Vector3.ZERO
				return jump_hang_squash
			return clampf(velocity.y * jump_air_stretch, -0.3, 0.45)

		JumpPhase.HANG:
			_air_time += delta
			velocity = Vector3.ZERO  # Cancels the gravity applied this frame.
			_update_shadow()
			if _state_timer >= jump_hang_time:
				_jump_phase = JumpPhase.SLAM
				_state_timer = 0.0
				_squash_velocity += jump_takeoff_kick
			return jump_hang_squash

		JumpPhase.SLAM:
			_air_time += delta
			velocity = Vector3(0.0, -jump_slam_speed, 0.0)
			_update_shadow()
			# Safety net: land even if something kept us off the floor.
			if is_on_floor() or _air_time > _jump_total_time * 2.0 + 1.0:
				_land_jump_attack()
				return 0.0
			return jump_slam_stretch

		_:  # RECOVER
			_apply_friction(delta)
			if _state_timer >= jump_recover_time:
				_set_state(State.HOP if _player_in_range(lose_range) else State.IDLE)
			return 0.0


## Rises to `jump_height` while drifting over `target` (the player's position
## at take-off), reaching the top right above it. Then HANG and SLAM take over,
## so moving away during the rise or hang dodges it.
func _launch_jump_attack(target: Vector3) -> void:
	_visual.position = Vector3.ZERO
	var from := global_position
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	if flat.length() > jump_max_distance:
		flat = flat.normalized() * jump_max_distance
	var gravity := maxf(get_gravity().length() * gravity_multiplier, 0.1)
	var rise := target.y - from.y
	# Apex must clear the landing height and stay under the ceiling.
	var apex := minf(jump_height, _headroom(from))
	apex = maxf(apex, rise + 1.0)
	var up_speed := sqrt(2.0 * gravity * apex)
	var time_up := up_speed / gravity
	velocity = flat / time_up + Vector3.UP * up_speed
	_jump_total_time = time_up + jump_hang_time + (apex - rise) / maxf(jump_slam_speed, 1.0)

	_jump_phase = JumpPhase.RISE
	_state_timer = 0.0
	_air_time = 0.0
	_squash_velocity += jump_takeoff_kick

	# Pass through the player while airborne so we land on them, not on their
	# head. Both directions, so the player's movement ignores us too.
	if _player:
		add_collision_exception_with(_player)
		_player.add_collision_exception_with(self)
		_jump_exception = _player

	_shadow.global_position = _find_floor(from + flat + Vector3.UP * rise) + Vector3.UP * 0.03
	_shadow.visible = true
	_update_shadow()


func _land_jump_attack() -> void:
	_jump_phase = JumpPhase.RECOVER
	_state_timer = 0.0
	velocity = Vector3.ZERO
	_squash_velocity += jump_landing_kick
	_splash.restart()
	_hide_jump_helpers()
	_play_shockwave()

	# Area damage: full at the centre, falling off to the edge of slam_radius.
	if _player_in_range(slam_radius + slam_max_height_difference):
		var offset := _player.global_position - global_position
		var flat := Vector2(offset.x, offset.z)
		var distance := flat.length()
		if distance <= slam_radius and absf(offset.y) <= slam_max_height_difference:
			var edge := clampf(distance / maxf(slam_radius, 0.01), 0.0, 1.0)
			var dir := Vector3(flat.x, 0.0, flat.y).normalized() if distance > 0.05 else -global_basis.z
			var knock := lerpf(1.0, slam_edge_knockback_factor, edge)
			_player.take_damage(slam_damage * lerpf(1.0, slam_edge_damage_factor, edge))
			_player.apply_knockback(dir * slam_knockback * knock + Vector3.UP * slam_knockback_up * knock)
			_contact_timer = contact_cooldown  # No extra bump right after.


## Ring that expands across the slam area and fades.
func _play_shockwave() -> void:
	if _shockwave_tween:
		_shockwave_tween.kill()
	_shockwave.global_position = global_position + Vector3.UP * 0.04
	_shockwave.scale = Vector3(0.3, 1.0, 0.3)
	_shockwave.visible = true
	var color := _shockwave_material.albedo_color
	color.a = 1.0
	_shockwave_material.albedo_color = color
	var faded := color
	faded.a = 0.0
	_shockwave_tween = create_tween().set_parallel(true)
	_shockwave_tween.tween_property(_shockwave, "scale", Vector3(slam_radius, 1.0, slam_radius), shockwave_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shockwave_tween.tween_property(_shockwave_material, "albedo_color", faded, shockwave_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shockwave_tween.chain().tween_callback(func() -> void: _shockwave.visible = false)


func _update_shadow() -> void:
	var progress := clampf(_air_time / maxf(_jump_total_time, 0.1), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, progress)
	var radius := lerpf(shadow_start_radius, slam_radius, eased)
	_shadow.scale = Vector3(radius, 1.0, radius)
	var color := _shadow_material.albedo_color
	color.a = lerpf(shadow_start_alpha, shadow_end_alpha, eased)
	_shadow_material.albedo_color = color


func _hide_jump_helpers() -> void:
	_visual.position = Vector3.ZERO
	_shadow.visible = false
	if _jump_exception != null and is_instance_valid(_jump_exception):
		remove_collision_exception_with(_jump_exception)
		_jump_exception.remove_collision_exception_with(self)
	_jump_exception = null


## How high the slime's origin can rise above `from` before its top touches
## the ceiling (or jump_height if nothing is above).
func _headroom(from: Vector3) -> float:
	const BODY_HEIGHT := 0.85
	var start := from + Vector3.UP * BODY_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(start, start + Vector3.UP * (jump_height + 1.0), 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return jump_height
	return maxf((hit.position as Vector3).y - start.y - jump_ceiling_margin, 0.5)


func _find_floor(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 6.0, 1)
	var exclude: Array[RID] = [get_rid()]
	if _player:
		exclude.append(_player.get_rid())
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return point if hit.is_empty() else (hit.position as Vector3)


# --- Fireball attack --------------------------------------------------------

func _can_fire_attack() -> bool:
	if _fire_cooldown_timer > 0.0 or fireball_scene == null or not is_on_floor():
		return false
	if not _player_in_range(fire_max_range):
		return false
	if global_position.distance_to(_player.global_position) < fire_min_range:
		return false
	return _has_line_of_sight()


func _state_fire_attack(delta: float) -> float:
	_apply_friction(delta)
	if _player_in_range(lose_range):
		_face(_player.global_position, delta)

	match _fire_phase:
		FirePhase.WINDUP:
			var progress := clampf(_state_timer / maxf(fire_windup_time, 0.01), 0.0, 1.0)
			_set_glow(progress)
			if _state_timer >= fire_windup_time:
				if _player_in_range(fire_max_range + 3.0):
					_shoot_fireball()
				_set_glow(0.0)
				_fire_phase = FirePhase.RECOVER
				_state_timer = 0.0
				return -fire_windup_swell
			# Swell up and quiver as it builds heat.
			return fire_windup_swell * progress + sin(_t * 30.0) * 0.02 * progress

		_:  # RECOVER
			if _state_timer >= fire_recover_time:
				_set_state(State.HOP if _player_in_range(lose_range) else State.IDLE)
			return 0.0


func _shoot_fireball() -> void:
	var fireball := fireball_scene.instantiate() as Fireball
	if fireball == null:
		return
	# The slime decides the projectile's stats, not the player's fireball tuning.
	fireball.min_damage = fire_damage
	fireball.max_damage = fire_damage
	fireball.min_knockback = fire_knockback
	fireball.max_knockback = fire_knockback
	fireball.min_speed = fire_projectile_speed
	fireball.max_speed = fire_projectile_speed
	fireball.min_gravity = fire_projectile_gravity
	fireball.max_gravity = fire_projectile_gravity
	fireball.min_splash_radius = fire_splash_radius
	fireball.max_splash_radius = fire_splash_radius
	fireball.min_splash_damage = fire_splash_damage
	fireball.max_splash_damage = fire_splash_damage
	fireball.splash_edge_factor = fire_splash_edge_factor
	get_tree().current_scene.add_child(fireball)

	var forward := global_basis.z  # Eyes are on local +Z.
	forward.y = 0.0
	forward = forward.normalized()
	var muzzle := global_position + Vector3.UP * fire_muzzle_height + forward * fire_muzzle_forward
	fireball.global_position = muzzle
	fireball.set_charge(fire_charge)

	# Aim a little high so the arc drops onto the player's chest.
	var target := _player.global_position + Vector3.UP * fire_aim_height
	var to_target := target - muzzle
	var flight_time := to_target.length() / maxf(fire_projectile_speed, 0.1)
	var aim := to_target + Vector3.UP * 0.5 * fire_projectile_gravity * flight_time * flight_time
	# Passing self as caster: the fireball ignores us and its blast won't push us.
	fireball.launch(aim, self)

	_squash_velocity -= 3.0
	velocity -= forward * fire_recoil


func _has_line_of_sight() -> bool:
	var from := global_position + Vector3.UP * fire_muzzle_height
	var to := _player.global_position + Vector3.UP * fire_aim_height
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid(), _player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## 0 = normal body glow, 1 = full fire glow. Skipped while a hit flash plays.
func _set_glow(amount: float) -> void:
	if _flash_tween and _flash_tween.is_running():
		return
	_body_material.emission = _base_emission.lerp(fire_glow_color, amount)
	_body_material.emission_energy_multiplier = lerpf(_base_emission_energy, fire_glow_energy, amount)


# --- Movement ---------------------------------------------------------------

func _hop_toward(target: Vector3) -> void:
	var to_target := target - global_position
	to_target.y = 0.0
	var dir := to_target.normalized() if to_target.length() > 0.01 else -global_basis.z
	velocity = dir * hop_speed + Vector3.UP * hop_up_velocity
	_squash_velocity += takeoff_kick
	_hop_timer = hop_interval


func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_squash_velocity += landing_kick
	_was_on_floor = on_floor


func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)


func _face(target: Vector3, delta: float) -> void:
	var to_target := target - global_position
	if Vector2(to_target.x, to_target.z).length() < 0.01:
		return
	var yaw := atan2(to_target.x, to_target.z)  # Eyes are on local +Z.
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_speed * delta))


func _player_in_range(distance: float) -> bool:
	return _player != null and is_instance_valid(_player) and not _player.is_dead \
		and global_position.distance_to(_player.global_position) <= distance


func _try_contact() -> void:
	if _contact_timer > 0.0 or not _player_in_range(contact_range + 1.0):
		return
	var offset := _player.global_position - global_position
	var flat := Vector2(offset.x, offset.z)
	if flat.length() > contact_range or absf(offset.y) > 1.2:
		return
	var dir := Vector3(flat.x, 0.0, flat.y).normalized() if flat.length() > 0.01 else -global_basis.z
	_player.take_damage(contact_damage)
	_player.apply_knockback(dir * contact_knockback + Vector3.UP * contact_knockback_up)
	velocity -= dir * 2.0  # Bounce off.
	_contact_timer = contact_cooldown


# --- Squash & stretch -------------------------------------------------------

## Spring toward the target squash so the body wobbles like jelly.
## Positive = taller and thinner, negative = flatter and wider (volume kept).
func _update_squash(delta: float, target: float) -> void:
	var accel := (target - _squash) * squash_stiffness - _squash_velocity * squash_damping
	_squash_velocity += accel * delta
	_squash = clampf(_squash + _squash_velocity * delta, -0.5, 0.6)
	var height := 1.0 + _squash
	var width := 1.0 / sqrt(maxf(height, 0.2))
	_visual.scale = Vector3(width, height, width)


# --- Damage -----------------------------------------------------------------

## Only IDLE / HOP can be interrupted, and not again until the knockback
## cooldown ends. Attacks keep going; the hit still hurts and flashes.
func _can_be_staggered() -> bool:
	return (state == State.IDLE or state == State.HOP) and _knockback_cooldown_timer <= 0.0


func take_damage(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_flash()
	_squash_velocity += hit_kick
	_label_timer = health_label_time
	if health <= 0.0:
		_die()
	elif _can_be_staggered():
		_set_state(State.HURT)
		_knockback_armed = true  # The knockback from this same hit is allowed.
		_knockback_cooldown_timer = knockback_cooldown


## Called by fireballs and explosions with an impulse-sized vector.
func apply_knockback(impulse: Vector3) -> void:
	if state == State.DEAD:
		return
	if not _knockback_armed:
		if not _can_be_staggered():
			return  # Mid-attack or on cooldown: ignore the push.
		_knockback_cooldown_timer = knockback_cooldown  # Near-miss blast push.
	velocity += impulse * knockback_scale
	if is_on_floor():
		velocity.y = maxf(velocity.y, knockback_lift)


func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_body_material.emission = flash_color
	_body_material.emission_energy_multiplier = flash_energy
	_flash_tween = create_tween().set_parallel(true)
	_flash_tween.tween_property(_body_material, "emission", _base_emission, flash_duration)
	_flash_tween.tween_property(_body_material, "emission_energy_multiplier", _base_emission_energy, flash_duration)


func _update_health_label(delta: float) -> void:
	if _label_timer <= 0.0 or state == State.DEAD:
		_health_label.visible = false
		return
	_label_timer -= delta
	_health_label.visible = true
	_health_label.text = "[%s]  %d / %d" % [InventoryItem.Grade.keys()[grade], ceili(health), roundi(max_health)]


# --- Death ------------------------------------------------------------------

func _die() -> void:
	if state == State.JUMP_ATTACK:
		_hide_jump_helpers()
	state = State.DEAD
	_state_timer = 0.0
	# Deferred: we're usually inside a fireball's physics callback.
	set_deferred("collision_layer", 0)
	_spawn_loot.call_deferred()
	if _player != null and is_instance_valid(_player):
		_player.gain_xp(randi_range(xp_min, xp_max))
	died.emit(self)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "scale", Vector3(1.7, 0.05, 1.7), death_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var faded := _body_material.albedo_color
	faded.a = 0.0
	tween.tween_property(_body_material, "albedo_color", faded, death_duration)
	tween.chain().tween_callback(queue_free)


func _spawn_loot() -> void:
	_roll_drop(core_item, core_chance)
	for _i in randi_range(jelly_min, jelly_max):
		_spawn_item(jelly_item)
	_roll_drop(crystal_item, crystal_chance)
	_roll_drop(royal_jelly_item, royal_jelly_chance)
	_roll_drop(royal_crystal_item, royal_crystal_chance)


func _roll_drop(item: InventoryItem, chance: float) -> void:
	if item != null and randf() < chance:
		_spawn_item(item)


func _spawn_item(item: InventoryItem) -> void:
	if item == null or item.world_scene == null:
		return
	var node := item.world_scene.instantiate() as Node3D
	if node == null:
		return
	if "item" in node:
		node.set("item", item)
	if "amount" in node:
		node.set("amount", 1)
	get_tree().current_scene.add_child(node)
	node.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.5, randf_range(-0.2, 0.2))
	var body := node as RigidBody3D
	if body:
		var angle := randf() * TAU
		var spread := Vector3(cos(angle), 0.0, sin(angle)) * loot_toss_speed * randf_range(0.5, 1.0)
		body.linear_velocity = spread + Vector3.UP * loot_toss_up
		body.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
