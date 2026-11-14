class_name ChargedProjectileCaster
extends SpellCaster
## Hold LMB to charge, release to fire (the fireball's way of casting).
## While held, the spell's `scene` sits on the Grimoire's cast point (or the
## player's muzzle). For the first `min_charge_time` seconds it is only
## gathering (embers spiralling in, faster and denser), and releasing
## cancels it for free. Then it forms and can be cast: releasing spends the
## spell's mana cost and launches it toward the crosshair. Holding longer
## changes nothing. Every cast is the same.
##
## The scene's root must have launch(direction, caster), get_radius() and a
## `damage_multiplier` property (see Fireball). Optional casting look on it:
## gather() at the start, set_gather_progress(0..1) until it's ready, form()
## when it is, scatter() if cancelled before that, fizzle() if cancelled
## after.

var _projectile: Node3D = null
var _charge_time: float = 0.0
## The minimum charge time has been reached: the spell can be cast.
var _castable: bool = false


func start(cast_spell: Spell, caster_player: Player) -> bool:
	spell = cast_spell
	player = caster_player
	if spell.scene == null or player.mana < spell.mana_cost:
		return false
	_projectile = spell.scene.instantiate() as Node3D
	if _projectile == null:
		return false
	_projectile.set("damage_multiplier", player.fireball_damage_multiplier)
	# Cast from the held book if it has a cast point, else the muzzle.
	var cast_point := player.held_item.get_cast_point()
	(cast_point if cast_point else player.muzzle).add_child(_projectile)
	_charge_time = 0.0
	_castable = false
	if spell.min_charge_time > 0.0 and _projectile.has_method("gather"):
		_projectile.call("gather")
	update(0.0)
	return true


func update(delta: float) -> void:
	if not is_instance_valid(_projectile):
		return
	if not _castable:
		_charge_time += delta
		if _charge_time >= spell.min_charge_time:
			_castable = true
			if _projectile.has_method("form"):
				_projectile.call("form")
		elif _projectile.has_method("set_gather_progress"):
			_projectile.call("set_gather_progress", _charge_time / spell.min_charge_time)
	_place()


func release() -> void:
	if not is_instance_valid(_projectile):
		return
	if not _castable:
		cancel()  # Released before the minimum charge: nothing cast, nothing spent.
		return
	var projectile := _projectile
	_projectile = null
	player.mana -= spell.mana_cost
	projectile.reparent(player.get_tree().current_scene)  # Keeps global transform.
	projectile.call("launch", player.aim_direction(projectile.global_position), player)


## Interrupted: the embers scatter (still gathering) or the fireball fizzles
## out (formed), staying in front of the camera even if the book it sat on is
## put away. Nothing is spent.
func cancel() -> void:
	if is_instance_valid(_projectile):
		var ending := "fizzle" if _castable else "scatter"
		if _projectile.has_method(ending) and _projectile.is_inside_tree():
			_projectile.reparent(player.camera)  # Keeps global transform.
			_projectile.call(ending)
		else:
			_projectile.queue_free()
	_projectile = null


## What releasing now would cost: nothing until it's ready, then the mana cost.
func pending_cost() -> float:
	return spell.mana_cost if is_instance_valid(_projectile) and _castable else 0.0


## Keep the projectile just above/ahead of the book, pushed out by its own
## radius so it floats in front of the hand instead of swallowing it.
func _place() -> void:
	if not is_instance_valid(_projectile) or _projectile.get_parent() == player.muzzle:
		return
	var radius := float(_projectile.call("get_radius"))
	var forward := -player.camera.global_basis.z
	var anchor := (_projectile.get_parent() as Node3D).global_position
	_projectile.global_position = anchor + forward * radius + Vector3.UP * radius * 0.6
