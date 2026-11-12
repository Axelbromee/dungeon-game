class_name Player
extends CharacterBody3D
## First-person player controller: mouse look, walk/sprint, jump, mana, a
## hold-to-charge fireball, world interaction and an inventory.

signal mana_changed(current: float, maximum: float)
## Mana the fireball being charged would cost if released now (0 = not charging).
signal charge_cost_changed(cost: float)
## Prompt for the interactable currently in focus ("" = nothing in focus).
signal interact_prompt_changed(text: String)
## Short feedback message for the HUD (pickups, drops, "inventory full").
signal notified(text: String)
## Active hotbar slot changed (index into the inventory's first row).
signal hotbar_selection_changed(index: int)
signal health_changed(current: float, maximum: float)
## Emitted each time damage is actually taken (not during invulnerability).
signal damaged(amount: float)
signal died
signal respawned
## `exhausted` = hit 0 and still refilling to the recovery threshold.
signal stamina_changed(current: float, maximum: float, exhausted: bool)
## A station wants to show a message panel (quest board, reception...).
signal info_shown(title: String, body: String)
## A storage chest was opened; the HUD shows it next to the bag.
signal storage_opened(storage: Inventory, title: String, on_close: Callable)

@export_group("Movement")
## Base speeds; Agility multiplies them.
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var ground_acceleration: float = 40.0
@export var air_acceleration: float = 8.0

@export_group("Stamina")
## Base maximum; Endurance adds to it.
@export var base_max_stamina: float = 100.0
@export var sprint_stamina_per_second: float = 15.0
@export var jump_stamina_cost: float = 10.0
## Base refill per second; Endurance adds to it.
@export var base_stamina_regen: float = 20.0
## Seconds without using stamina before it starts refilling.
@export var stamina_regen_delay: float = 1.0
## After hitting 0, sprint/jump/dash stay locked until stamina reaches this.
@export var exhausted_recover_threshold: float = 20.0

@export_group("Dash")
@export var dash_stamina_cost: float = 25.0
@export var dash_speed: float = 14.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.6
## Invulnerable to damage while dashing.
@export var dash_invulnerable: bool = true

@export_group("Stairs")
## Tallest ledge the player walks up without jumping.
@export var max_step_height: float = 0.35
## How quickly the camera catches up after a step (hides the snap).
@export var step_camera_smoothing: float = 14.0

@export_group("Jump")
@export var jump_velocity: float = 4.5
## Time after walking off a ledge during which a jump still works.
@export var coyote_time: float = 0.12
## Time a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12

@export_group("Look")
@export var mouse_sensitivity: float = 0.002
@export_range(0.0, 90.0) var max_pitch_degrees: float = 80.0
## Vertical field of view of the first-person camera (degrees).
@export_range(40.0, 120.0) var camera_fov: float = 90.0:
	set(value):
		camera_fov = value
		if is_node_ready():
			camera.fov = value

@export_group("Health")
## Base maximum; Vitality adds to it.
@export var base_max_health: float = 100.0
## Seconds of invulnerability after taking a hit.
@export var hurt_invulnerability: float = 0.6
## Seconds between dying and respawning.
@export var respawn_delay: float = 1.5

@export_group("Mana")
## Base maximum; Magic adds to it.
@export var base_max_mana: float = 100.0
## Regeneration per second. Paused while charging.
@export var mana_regen_per_second: float = 10.0

@export_group("Fireball")
@export var fireball_scene: PackedScene
## Item that must be the selected hotbar item to charge/cast. Empty = always allowed.
@export var spell_item: InventoryItem
## Seconds of holding to reach full charge.
@export var max_charge_time: float = 1.5
## Cost of an uncharged shot; also the minimum mana needed to start casting.
@export var min_mana_cost: float = 5.0
## Cost of a fully charged shot.
@export var max_mana_cost: float = 40.0
## How far ahead the crosshair ray looks when computing the aim point.
@export var aim_distance: float = 100.0
## Layers the crosshair ray can hit (excludes the invisible stair ramps).
@export_flags_3d_physics var aim_mask: int = 1

@export_group("Interaction")
## How far the look-at ray reaches.
@export var interact_distance: float = 2.6
## Layers holding interactables (layer 3 = "interactable").
@export_flags_3d_physics var interact_mask: int = 4
## Layers that block the interaction ray / drop placement (walls, floor).
@export_flags_3d_physics var world_mask: int = 1
## How far in front of the player dropped items land.
@export var drop_distance: float = 1.3
## Forward / upward speed given to dropped physics items (RigidBody3D).
@export var drop_toss_speed: float = 2.5
@export var drop_toss_up: float = 1.5

@export_group("Hotbar")
## Slots in the hotbar (first row of the inventory). Number keys 1-9 map to them.
@export_range(1, 9) var hotbar_size: int = 9
## New game: put the spell item (the Fire Spellbook) in hotbar slot 1, selected.
@export var start_with_spell_item: bool = true
## Extra items given on a new game (into the bag).
@export var starting_items: Array[InventoryItem] = []

# Derived from the base values above plus PlayerStats (see _apply_stats()).
var max_health: float = 100.0
var max_mana: float = 100.0
var max_stamina: float = 100.0
var stamina_regen: float = 20.0
var speed_multiplier: float = 1.0
var fireball_damage_multiplier: float = 1.0
## Uncharged / fully charged direct damage of fireball_scene (before Magic).
var fireball_base_damage: Vector2 = Vector2(10.0, 50.0)

var stamina: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, max_stamina)
		if clamped != stamina:
			stamina = clamped
			stamina_changed.emit(stamina, max_stamina, is_exhausted)

var is_exhausted: bool = false
var _stamina_regen_timer: float = 0.0
var _is_sprinting: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO

var mana: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, max_mana)
		if clamped != mana:
			mana = clamped
			mana_changed.emit(mana, max_mana)

var health: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, max_health)
		if clamped != health:
			health = clamped
			health_changed.emit(health, max_health)

var is_dead: bool = false
var selected_hotbar_index: int = 0
var _invulnerable_timer: float = 0.0
var _spawn_transform: Transform3D

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _charging_fireball: Fireball = null
var _charge_time: float = 0.0
var _camera_base_y: float = 0.0
var _ui_open: bool = false
var _focused: Node3D = null
var _last_prompt: String = ""

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var muzzle: Marker3D = $CameraPivot/Muzzle
@onready var inventory: Inventory = $Inventory
@onready var held_item: HeldItemView = $CameraPivot/Camera3D/Hand
@onready var stats: PlayerStats = $Stats
@onready var _interaction_area: Area3D = $InteractionArea


func _enter_tree() -> void:
	# Joined before any _ready() runs, so the HUD and enemies can find us
	# whatever order the scene lists them in.
	add_to_group("player")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = camera_fov
	_read_fireball_damage()
	_apply_stats()
	mana = max_mana
	health = max_health
	stamina = max_stamina
	stats.stats_changed.connect(_apply_stats)
	stats.leveled_up.connect(_on_leveled_up)
	_spawn_transform = global_transform
	_camera_base_y = camera_pivot.position.y
	inventory.hotbar_size = hotbar_size
	if GameState.has_player_data():
		load_state(GameState.player_data)  # Coming from another scene.
	else:
		# New game.
		if start_with_spell_item and spell_item:
			inventory.set_slot(0, spell_item, 1)
		selected_hotbar_index = 0
		for item in starting_items:
			if item:
				inventory.add_item(item, 1)
	inventory.slot_changed.connect(_on_inventory_slot_changed)
	_refresh_held_item()
	# Spawn points may not be ready yet; place the player after the scene is.
	_go_to_spawn_point.call_deferred(GameState.pending_spawn)
	GameState.pending_spawn = &""


func _process(delta: float) -> void:
	# Ease the camera back to eye height after a step-up.
	var t := 1.0 - exp(-step_camera_smoothing * delta)
	camera_pivot.position.y = lerpf(camera_pivot.position.y, _camera_base_y, t)


func _unhandled_input(event: InputEvent) -> void:
	if _ui_open or is_dead:
		return  # Inventory owns the mouse / dead: no look, cast or interact.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_cancel_charge()
		return

	if not captured:
		# Click back into the game to recapture the mouse (without casting).
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return

	var hotbar_step := _hotbar_scroll_step(event)
	var hotbar_key := _hotbar_key_index(event)

	if event is InputEventMouseMotion:
		_look(event.relative)
	elif hotbar_step != 0:
		select_hotbar(selected_hotbar_index + hotbar_step)
	elif hotbar_key >= 0:
		select_hotbar(hotbar_key)
	elif event.is_action_pressed("drop_item"):
		drop_from_slot(selected_hotbar_index, 1)
	elif event.is_action_pressed("cast"):
		_start_charge()
	elif event.is_action_released("cast"):
		_release_charge()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("dash"):
		_try_dash()


func _physics_process(delta: float) -> void:
	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
	if is_dead:
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, ground_acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_acceleration * delta)
		move_and_slide()
		return
	_dash_cooldown_timer -= delta
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_movement(delta)
	_handle_dash(delta)
	_try_step_up(delta)
	move_and_slide()
	_update_charge(delta)
	_regen_mana(delta)
	_update_stamina(delta)
	_update_focus()


# --- Look & movement --------------------------------------------------------

func _look(relative: Vector2) -> void:
	held_item.add_look_input(relative)
	rotate_y(-relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(-relative.y * mouse_sensitivity)
	var max_pitch := deg_to_rad(max_pitch_degrees)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -max_pitch, max_pitch)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _handle_jump(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump_buffer_timer = 0.0
		if _has_stamina():
			velocity.y = jump_velocity
			_coyote_timer = 0.0
			_spend_stamina(jump_stamina_cost)

	# Release jump early for a shorter hop.
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var wants_sprint := Input.is_action_pressed("sprint") and input_dir.length() > 0.1
	_is_sprinting = wants_sprint and _has_stamina()
	if _is_sprinting and is_on_floor():
		_spend_stamina(sprint_stamina_per_second * delta)
	var speed := (sprint_speed if _is_sprinting else walk_speed) * speed_multiplier
	var target := direction * speed
	var accel := ground_acceleration if is_on_floor() else air_acceleration

	var horizontal := Vector2(velocity.x, velocity.z)
	horizontal = horizontal.move_toward(Vector2(target.x, target.z), accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y


## Quick burst in the move direction (or forward if standing still).
func _try_dash() -> void:
	if _dash_cooldown_timer > 0.0 or not _has_stamina():
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	_dash_direction = direction.normalized() if direction.length() > 0.1 else _flat_forward()
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_spend_stamina(dash_stamina_cost)
	if dash_invulnerable:
		_invulnerable_timer = maxf(_invulnerable_timer, dash_duration)


func _handle_dash(delta: float) -> void:
	if _dash_timer <= 0.0:
		return
	_dash_timer -= delta
	var dash_velocity := _dash_direction * dash_speed * speed_multiplier
	velocity.x = dash_velocity.x
	velocity.z = dash_velocity.z


# --- Stamina ----------------------------------------------------------------

## False at 0 stamina and until it refills to exhausted_recover_threshold.
func _has_stamina() -> bool:
	return not is_exhausted and stamina > 0.0


func _spend_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	_stamina_regen_timer = stamina_regen_delay
	stamina -= amount
	if stamina <= 0.0 and not is_exhausted:
		is_exhausted = true
		stamina_changed.emit(stamina, max_stamina, is_exhausted)


func _update_stamina(delta: float) -> void:
	if _stamina_regen_timer > 0.0:
		_stamina_regen_timer -= delta
		return
	if stamina < max_stamina:
		stamina += stamina_regen * delta
	if is_exhausted and stamina >= minf(exhausted_recover_threshold, max_stamina):
		is_exhausted = false
		stamina_changed.emit(stamina, max_stamina, is_exhausted)


# --- Scenes, saving & stations ----------------------------------------------

## Everything that should survive a scene change.
func save_state() -> Dictionary:
	return {
		"inventory": inventory.to_data(),
		"stats": stats.to_data(),
		"health": health,
		"mana": mana,
		"stamina": stamina,
		"selected_hotbar": selected_hotbar_index,
	}


func load_state(data: Dictionary) -> void:
	stats.from_data(data.get("stats", {}))
	_apply_stats()
	inventory.from_data(data.get("inventory", []))
	health = float(data.get("health", max_health))
	mana = float(data.get("mana", max_mana))
	stamina = float(data.get("stamina", max_stamina))
	selected_hotbar_index = clampi(int(data.get("selected_hotbar", 0)), 0, hotbar_size - 1)
	hotbar_selection_changed.emit(selected_hotbar_index)
	if health <= 0.0:
		health = max_health  # Never arrive dead.


## Moves to the SpawnPoint with `spawn_id` (or "default"), facing its -Z,
## and makes it the respawn point. Keeps the editor position if neither exists.
func _go_to_spawn_point(spawn_id: StringName) -> void:
	if not is_inside_tree():
		return  # Scene was swapped out in the same frame.
	var fallback: SpawnPoint = null
	var chosen: SpawnPoint = null
	for node in get_tree().get_nodes_in_group("spawn_points"):
		var point := node as SpawnPoint
		if point == null:
			continue
		if spawn_id != &"" and point.spawn_id == spawn_id:
			chosen = point
			break
		if point.spawn_id == &"default":
			fallback = point
	if chosen == null:
		chosen = fallback
	if chosen == null:
		_spawn_transform = global_transform
		return
	var yaw := chosen.global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), chosen.global_position)
	camera_pivot.rotation.x = 0.0
	velocity = Vector3.ZERO
	_spawn_transform = global_transform


## Bed: restore everything.
func rest() -> void:
	if is_dead:
		return
	health = max_health
	mana = max_mana
	is_exhausted = false
	stamina = max_stamina
	notified.emit("You feel well rested")


func show_info(title: String, body: String) -> void:
	info_shown.emit(title, body)


## Storage chest: show `storage` next to the bag. `on_close` runs when the
## inventory window closes (e.g. to shut the chest lid).
func open_storage(storage: Inventory, title: String, on_close: Callable = Callable()) -> void:
	storage_opened.emit(storage, title, on_close)


# --- Level & stats ----------------------------------------------------------

## Called by enemies when they die.
func gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	notified.emit("+%d XP" % amount)
	stats.add_xp(amount)


func _on_leveled_up(new_level: int) -> void:
	notified.emit("Level up!  Level %d" % new_level)


## Recompute every stat-derived value. Gaining max HP/mana/stamina also adds
## the difference to the current value, so a point in Vitality heals too.
func _apply_stats() -> void:
	var old_health_max := max_health
	var old_mana_max := max_mana
	var old_stamina_max := max_stamina
	max_health = base_max_health + stats.health_bonus()
	max_mana = base_max_mana + stats.mana_bonus()
	max_stamina = base_max_stamina + stats.stamina_bonus()
	stamina_regen = base_stamina_regen + stats.stamina_regen_bonus()
	speed_multiplier = 1.0 + stats.speed_bonus()
	fireball_damage_multiplier = 1.0 + stats.fireball_damage_bonus()
	if not is_dead:
		health += maxf(max_health - old_health_max, 0.0)
		mana += maxf(max_mana - old_mana_max, 0.0)
		stamina += maxf(max_stamina - old_stamina_max, 0.0)
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	stamina_changed.emit(stamina, max_stamina, is_exhausted)


func _read_fireball_damage() -> void:
	if fireball_scene == null:
		return
	var probe := fireball_scene.instantiate() as Fireball
	if probe:
		fireball_base_damage = Vector2(probe.min_damage, probe.max_damage)
		probe.free()


## If a low ledge blocks this frame's horizontal motion, lift the body onto it.
## Probe: blocked ahead -> room above -> clear ahead when raised -> walkable
## ground below. move_and_slide() then does the horizontal move as usual.
func _try_step_up(delta: float) -> void:
	if not is_on_floor() or velocity.y > 0.0:
		return
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return

	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return  # Nothing in the way.
	if hit.get_normal().angle_to(Vector3.UP) <= floor_max_angle:
		return  # It's a walkable slope; move_and_slide handles it.

	var up := Vector3.UP * max_step_height
	var probe := global_transform
	if test_move(probe, up):
		return  # Ceiling too low.
	probe.origin += up
	# Look slightly further ahead so the capsule clears the ledge edge.
	var ahead := motion.normalized() * maxf(motion.length(), 0.05)
	if test_move(probe, ahead):
		return  # Still blocked when raised: it's a wall, not a step.
	probe.origin += ahead

	var ground := KinematicCollision3D.new()
	if not test_move(probe, -up, ground):
		return  # No ground to land on.
	if ground.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return

	var rise := up.y + ground.get_travel().y
	if rise <= 0.001:
		return
	global_position.y += rise
	# Keep the eyes where they were; _process() glides them back up.
	camera_pivot.position.y = maxf(camera_pivot.position.y - rise, _camera_base_y - max_step_height * 2.0)


# --- Health -----------------------------------------------------------------

## Called by enemies and hazards. Ignored while dead or briefly after a hit.
func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0 or _invulnerable_timer > 0.0:
		return
	_invulnerable_timer = hurt_invulnerability
	health -= amount
	damaged.emit(amount)
	if health <= 0.0:
		_die()


## Instant velocity change (e.g. an enemy bump). Ignored while dead.
func apply_knockback(impulse: Vector3) -> void:
	if is_dead:
		return
	velocity += impulse


func _die() -> void:
	is_dead = true
	_cancel_charge()
	held_item.visible = false
	notified.emit("You died")
	died.emit()
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	camera_pivot.rotation.x = 0.0
	health = max_health
	mana = max_mana
	is_exhausted = false
	stamina = max_stamina
	_dash_timer = 0.0
	_invulnerable_timer = hurt_invulnerability * 2.0
	is_dead = false
	held_item.visible = true
	respawned.emit()


# --- Mana -------------------------------------------------------------------

func _regen_mana(delta: float) -> void:
	if _charging_fireball == null:
		mana += mana_regen_per_second * delta


## Highest charge ratio the current mana can pay for.
func _affordable_charge_ratio() -> float:
	if max_mana_cost <= min_mana_cost:
		return 1.0 if mana >= min_mana_cost else 0.0
	return clampf(inverse_lerp(min_mana_cost, max_mana_cost, mana), 0.0, 1.0)


func _cost_for(charge_ratio: float) -> float:
	return lerpf(min_mana_cost, max_mana_cost, charge_ratio)


# --- Fireball ---------------------------------------------------------------

func _can_cast() -> bool:
	return spell_item == null or spell_item.is_same_item(get_selected_item())


func _start_charge() -> void:
	if _charging_fireball != null or fireball_scene == null:
		return
	if not _can_cast():
		notified.emit("Select the %s on your hotbar to cast" % spell_item.item_name)
		return
	if mana < min_mana_cost:
		return
	_charging_fireball = fireball_scene.instantiate() as Fireball
	_charging_fireball.damage_multiplier = fireball_damage_multiplier
	# Charge from the held book if it has a cast point, else the muzzle.
	var cast_point := held_item.get_cast_point()
	(cast_point if cast_point else muzzle).add_child(_charging_fireball)
	_charge_time = 0.0
	_place_charging_fireball()


func _update_charge(delta: float) -> void:
	if _charging_fireball == null:
		return
	if not _can_cast():
		_cancel_charge()  # Spellbook deselected or dropped mid-charge.
		return
	_charge_time = minf(_charge_time + delta, max_charge_time)
	var time_ratio := _charge_time / max_charge_time if max_charge_time > 0.0 else 1.0
	# Growth stops at whatever size the available mana can afford.
	_charging_fireball.set_charge(minf(time_ratio, _affordable_charge_ratio()))
	_place_charging_fireball()
	charge_cost_changed.emit(_cost_for(_charging_fireball.charge_ratio))


## Keep a growing fireball just above/ahead of the book, pushed out by its own
## radius so a full charge floats in front of the hand instead of swallowing it.
func _place_charging_fireball() -> void:
	if _charging_fireball == null or _charging_fireball.get_parent() == muzzle:
		return
	var radius := _charging_fireball.get_radius()
	var forward := -camera.global_basis.z
	var anchor := (_charging_fireball.get_parent() as Node3D).global_position
	_charging_fireball.global_position = anchor + forward * radius + Vector3.UP * radius * 0.6


func _release_charge() -> void:
	if _charging_fireball == null:
		return
	var fireball := _charging_fireball
	_charging_fireball = null

	mana -= _cost_for(fireball.charge_ratio)
	charge_cost_changed.emit(0.0)
	fireball.reparent(get_tree().current_scene)  # Keeps global transform.
	fireball.launch(_aim_direction(fireball.global_position), self)


func _cancel_charge() -> void:
	if _charging_fireball != null:
		if is_instance_valid(_charging_fireball):
			_charging_fireball.queue_free()
		_charging_fireball = null
		charge_cost_changed.emit(0.0)


## Direction from `from` toward whatever the crosshair is pointing at, so the
## offset muzzle still converges on screen centre.
func _aim_direction(from: Vector3) -> Vector3:
	var cam_origin := camera.global_position
	var cam_forward := -camera.global_basis.z
	var target := cam_origin + cam_forward * aim_distance
	var query := PhysicsRayQueryParameters3D.create(cam_origin, target, aim_mask)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position
	var dir := target - from
	# Target too close (e.g. hugging a wall): fall back to camera forward.
	return dir.normalized() if dir.length() > 0.5 else cam_forward


# --- UI state ---------------------------------------------------------------

## Called by the HUD when the inventory opens/closes.
func set_ui_open(open: bool) -> void:
	_ui_open = open
	if open:
		_cancel_charge()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_prompt()


# --- Interaction ------------------------------------------------------------

func _interact() -> void:
	if _focused != null and is_instance_valid(_focused):
		_focused.call("interact", self)


func _update_focus() -> void:
	if not is_instance_valid(_focused):
		_focused = null  # Freed objects can compare equal to null; check validity.
	var target := _find_interactable()
	if target != _focused:
		if _focused != null and _focused.has_method("set_highlighted"):
			_focused.call("set_highlighted", false)
		_focused = target
		if _focused != null and _focused.has_method("set_highlighted"):
			_focused.call("set_highlighted", true)
	_emit_prompt()


## Prefer what the crosshair is on; otherwise the nearest interactable in
## front of the player inside the InteractionArea.
func _find_interactable() -> Node3D:
	var from := camera.global_position
	var to := from - camera.global_basis.z * interact_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, interact_mask | world_mask)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var looked_at := _as_interactable(hit.collider)
		if looked_at != null:
			return looked_at

	var forward := -global_basis.z
	var best: Node3D = null
	var best_score := -INF
	var nearby: Array = []
	nearby.append_array(_interaction_area.get_overlapping_areas())
	nearby.append_array(_interaction_area.get_overlapping_bodies())
	for overlap in nearby:
		var candidate := _as_interactable(overlap)
		if candidate == null:
			continue
		var offset := candidate.global_position - global_position
		offset.y = 0.0
		var facing := forward.dot(offset.normalized()) if offset.length() > 0.05 else 1.0
		if facing < 0.4:
			continue  # Behind or beside us.
		var score := facing - offset.length() * 0.35
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _as_interactable(obj: Object) -> Node3D:
	var node := obj as Node
	for _i in 4:
		if node == null:
			return null
		if node.has_method("interact") and node.has_method("get_interaction_text"):
			return node as Node3D
		node = node.get_parent()
	return null


func _emit_prompt() -> void:
	var text := ""
	if not _ui_open and _focused != null and is_instance_valid(_focused):
		text = "Press [%s] to %s" % [_action_key_label("interact"), str(_focused.call("get_interaction_text"))]
	if text != _last_prompt:
		_last_prompt = text
		interact_prompt_changed.emit(text)


static func _action_key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "?"


# --- Hotbar -----------------------------------------------------------------

func select_hotbar(index: int) -> void:
	index = posmod(index, hotbar_size)
	if index == selected_hotbar_index:
		return
	selected_hotbar_index = index
	_refresh_held_item()
	hotbar_selection_changed.emit(index)


func _on_inventory_slot_changed(index: int) -> void:
	if index == selected_hotbar_index:
		_refresh_held_item()


## Show the selected item in the hand. If that takes the spellbook away
## mid-charge, cancel first so the fireball isn't freed along with the book.
func _refresh_held_item() -> void:
	if _charging_fireball != null and not _can_cast():
		_cancel_charge()
	held_item.set_item(get_selected_item())


func get_selected_item() -> InventoryItem:
	return inventory.get_item(selected_hotbar_index)


## -1 / +1 for mouse wheel up / down, 0 otherwise.
func _hotbar_scroll_step(event: InputEvent) -> int:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return 0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		return -1
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return 1
	return 0


## Hotbar index for number keys 1-9, or -1.
func _hotbar_key_index(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return -1
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code >= KEY_1 and code <= KEY_9:
		var index := int(code - KEY_1)
		return index if index < hotbar_size else -1
	return -1


# --- Inventory --------------------------------------------------------------

## Adds items and reports the result. Returns how many did NOT fit.
func give_item(item: InventoryItem, amount: int = 1) -> int:
	var leftover := inventory.add_item(item, amount)
	var added := amount - leftover
	if added > 0:
		notified.emit("+%d %s" % [added, item.item_name])
	if leftover > 0:
		notified.emit("Inventory full")
	return leftover


## Removes `amount` from a slot and spawns it in the world in front of us.
func drop_from_slot(index: int, amount: int) -> void:
	var item := inventory.get_item(index)
	if item == null:
		return
	if item.world_scene == null:
		notified.emit("%s can't be dropped" % item.item_name)
		return
	var removed := inventory.remove_from_slot(index, amount)
	if removed > 0:
		drop_item_stack(item, removed)


## Spawns `amount` of `item` in front of the player (already taken out of
## whatever inventory it came from).
func drop_item_stack(item: InventoryItem, amount: int) -> void:
	if item == null or amount <= 0 or item.world_scene == null:
		return
	var first := item.world_scene.instantiate()
	if "amount" in first:
		# Scene can represent a whole stack: spawn once.
		_spawn_dropped(first as Node3D, item, amount, Vector3.ZERO)
	else:
		# One node per unit, slightly spread out.
		_spawn_dropped(first as Node3D, item, 1, Vector3.ZERO)
		for _i in range(1, amount):
			var extra := item.world_scene.instantiate() as Node3D
			var spread := Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
			_spawn_dropped(extra, item, 1, spread)
	notified.emit("Dropped %d %s" % [amount, item.item_name])


func _spawn_dropped(node: Node3D, item: InventoryItem, amount: int, offset: Vector3) -> void:
	if node == null:
		return
	if "item" in node:
		node.set("item", item)
	if "amount" in node:
		node.set("amount", amount)
	if "verb" in node:
		node.set("verb", "Pick up")
	get_tree().current_scene.add_child(node)

	var body := node as RigidBody3D
	if body == null:
		# Static pickup: place it on the floor.
		node.global_position = _drop_position() + offset
		node.rotate_y(randf() * TAU)
		return

	# Physics pickup: toss it from chest height so it falls and bounces.
	body.global_position = _toss_origin() + offset
	body.rotate_y(randf() * TAU)
	var forward := _flat_forward()
	var inherited := Vector3(velocity.x, 0.0, velocity.z) * 0.5
	body.linear_velocity = forward * drop_toss_speed + Vector3.UP * drop_toss_up + inherited
	body.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	# Never let a fresh drop shove the player; re-enable contact after it's clear.
	body.add_collision_exception_with(self)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.remove_collision_exception_with(self)
	)


func _flat_forward() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Chest-height point in front of the player, pulled back from walls.
func _toss_origin() -> Vector3:
	var forward := _flat_forward()
	var chest := global_position + Vector3.UP * 1.2
	var target := chest + forward * 0.8
	var query := PhysicsRayQueryParameters3D.create(chest, target, world_mask)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = (hit.position as Vector3) - forward * 0.3
	return target


## A floor point ~drop_distance ahead, pulled back if a wall is in the way.
func _drop_position() -> Vector3:
	var space := get_world_3d().direct_space_state
	var forward := _flat_forward()
	var chest := global_position + Vector3.UP * 1.0
	var target := chest + forward * drop_distance
	var wall_query := PhysicsRayQueryParameters3D.create(chest, target, world_mask)
	wall_query.exclude = [get_rid()]
	var wall_hit := space.intersect_ray(wall_query)
	if not wall_hit.is_empty():
		target = (wall_hit.position as Vector3) - forward * 0.3

	var floor_query := PhysicsRayQueryParameters3D.create(target, target + Vector3.DOWN * 5.0, world_mask)
	floor_query.exclude = [get_rid()]
	var floor_hit := space.intersect_ray(floor_query)
	if floor_hit.is_empty():
		return Vector3(target.x, global_position.y, target.z)
	return floor_hit.position
