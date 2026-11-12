class_name Harvestable
extends Area3D
## World forageable: herbs, berries, moss, ore... The Player's interaction ray
## finds this Area3D (physics layer 3, "interactable") and calls interact().
##
## - Takes `hits_to_harvest` presses of E (ore: 3); each press shakes it.
## - Gives `amount` items, or a random amount..amount_max, straight into the
##   inventory or, with drop_as_pickups, tossed out as pickups (ore).
## - Disappears when harvested, or with regrow_time > 0 stays and regrows:
##   the `regrow_nodes` (e.g. berries) hide until then.
## A SpawnArea counts it as gone (and refills the slot) when it's removed.

signal harvested(player: Player)

@export var item: InventoryItem
@export_range(1, 999) var amount: int = 1
## Above `amount`: a random amount from amount to amount_max. 0 = always `amount`.
@export_range(0, 999) var amount_max: int = 0
## Verb shown in the prompt, e.g. "Harvest", "Pick" or "Mine".
@export var verb: String = "Harvest"
## Presses of E needed (ore: 3).
@export_range(1, 20) var hits_to_harvest: int = 1
## Toss the items out as pickups instead of putting them in the inventory.
@export var drop_as_pickups: bool = false

@export_group("Regrow")
## Seconds until it can be harvested again. 0 = it disappears when harvested.
@export var regrow_time: float = 0.0
## Hidden while regrowing (e.g. the berries, not the bush).
@export var regrow_nodes: Array[NodePath] = []

@export_group("Feedback")
## Wobbles on every press (e.g. the rock of an ore node).
@export var shake_node: Node3D
@export var shake_strength: float = 0.06
## Restarted on every press (e.g. flying rock chips).
@export var hit_particles: GPUParticles3D

@export_group("Glow")
## MeshInstance3D whose material_override glows and brightens when targeted.
## Every mesh below this node sharing that material pulses with it.
@export var glow_mesh: MeshInstance3D
@export var base_glow: float = 2.5
@export var highlight_glow: float = 7.0
@export var pulse_speed: float = 1.2

@export_group("Tint")
## Multiplies the colour of every mesh below this node (in the game), e.g.
## to darken a shared KayKit rock.
@export var tint_root: Node3D
@export var model_tint: Color = Color.WHITE

static var _highlight_material: StandardMaterial3D

var _glow_material: StandardMaterial3D
var _highlighted: bool = false
var _t: float = 0.0
var _hits: int = 0
## Items still owed after a full inventory (-1 = not rolled yet).
var _owed: int = -1
var _regrowing: bool = false
var _layer: int = 0
var _meshes: Array[Node] = []
var _shake_tween: Tween
var _shake_home: Vector3


func _ready() -> void:
	_t = randf() * 10.0
	_layer = collision_layer
	if shake_node:
		_shake_home = shake_node.position
	if glow_mesh and glow_mesh.material_override is StandardMaterial3D:
		# Own copy so highlighting one plant doesn't light up all of them.
		var shared := glow_mesh.material_override
		_glow_material = shared.duplicate() as StandardMaterial3D
		for node in [glow_mesh] + find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.material_override == shared:
				mesh.material_override = _glow_material
	if tint_root and model_tint != Color.WHITE:
		_apply_tint()
	_meshes = find_children("*", "MeshInstance3D", true, false)


func _process(delta: float) -> void:
	if _glow_material == null:
		return
	_t += delta
	var target := highlight_glow if _highlighted else base_glow
	var pulse := 0.85 + 0.15 * sin(_t * pulse_speed * TAU)
	_glow_material.emission_energy_multiplier = target * pulse


func get_interaction_text() -> String:
	var item_name := item.item_name if item else "???"
	var count := _owed if _owed > 0 else amount
	var suffix := " (x%d)" % count if count > 1 and (amount_max <= amount or _owed > 0) else ""
	if hits_to_harvest > 1:
		suffix += "  %d/%d" % [_hits, hits_to_harvest]
	return "%s %s%s" % [verb, item_name, suffix]


func set_highlighted(on: bool) -> void:
	_highlighted = on
	if _glow_material != null:
		return
	# No glow: show the same soft overlay as dropped pickups.
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_highlight_material.albedo_color = Color(0.55, 0.85, 1.0, 0.22)
	for mesh in _meshes:
		if is_instance_valid(mesh):
			(mesh as MeshInstance3D).material_overlay = _highlight_material if on else null


func interact(player: Player) -> void:
	if item == null or _regrowing:
		return
	if _owed < 0:
		_hits += 1
		_shake()
		if hit_particles:
			hit_particles.restart()
		if _hits < hits_to_harvest:
			return
		_owed = randi_range(amount, amount_max) if amount_max > amount else amount

	if drop_as_pickups:
		for _i in _owed:
			_drop_pickup()
		_owed = 0
	else:
		_owed = player.give_item(item, _owed)
		if _owed > 0:
			return  # Inventory full: the rest waits here.
	harvested.emit(player)
	_finish()


func _finish() -> void:
	_hits = 0
	_owed = -1
	if regrow_time <= 0.0:
		queue_free()
		return
	_regrowing = true
	set_highlighted(false)
	_show_regrow_nodes(false)
	# Off the interactable layer, so the player can't target it meanwhile.
	collision_layer = 0
	get_tree().create_timer(regrow_time).timeout.connect(_regrow)


func _regrow() -> void:
	_regrowing = false
	collision_layer = _layer
	_show_regrow_nodes(true)


func _show_regrow_nodes(on: bool) -> void:
	for path in regrow_nodes:
		var node := get_node_or_null(path) as Node3D
		if node:
			node.visible = on


func _shake() -> void:
	if shake_node == null:
		return
	if _shake_tween:
		_shake_tween.kill()
	shake_node.position = _shake_home
	_shake_tween = create_tween()
	for i in 4:
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * shake_strength * (1.0 - i * 0.22)
		_shake_tween.tween_property(shake_node, "position", _shake_home + offset, 0.04)
	_shake_tween.tween_property(shake_node, "position", _shake_home, 0.05)


func _drop_pickup() -> void:
	if item.world_scene == null:
		return
	var node := item.world_scene.instantiate() as Node3D
	if node == null:
		return
	if "item" in node:
		node.set("item", item)
	if "amount" in node:
		node.set("amount", 1)
	get_tree().current_scene.add_child(node)
	# Tossed out of the front (+Z) and up.
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	node.global_position = global_position + Vector3.UP * 0.8 + forward * 0.7
	var body := node as RigidBody3D
	if body:
		var side := forward.cross(Vector3.UP) * randf_range(-1.2, 1.2)
		body.linear_velocity = forward * randf_range(1.5, 2.5) + side + Vector3.UP * randf_range(2.0, 3.0)
		body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))


func _apply_tint() -> void:
	for node in [tint_root] + tint_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source == null:
				continue
			var tinted := source.duplicate() as StandardMaterial3D
			tinted.albedo_color = source.albedo_color * model_tint
			mesh.set_surface_override_material(i, tinted)
