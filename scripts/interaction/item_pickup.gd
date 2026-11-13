class_name ItemPickup
extends RigidBody3D
## A physical item lying in the world (what you get when dropping from the
## inventory). Tumbles a little when dropped, then settles and stops, and can
## be picked up with the interact key. Lives on physics layer 3
## ("interactable") and collides with the world. An outline in the item's
## grade colour makes it easy to spot on the ground (only here: the held
## model and inventory icons are built without this script).

const OUTLINE_SHADER := preload("res://shaders/effects/pickup_outline.gdshader")

## Set per placed pickup in the Inspector. Left empty, default_item is used.
@export var item: InventoryItem
@export_range(1, 999) var amount: int = 1
@export var verb: String = "Pick up"
## Pickups that fall below this height are removed.
@export var kill_height: float = -50.0
## Item file used when `item` is empty, so the pickup scene works when simply
## dragged into a level. It's a path, not a resource: the item already points
## at this scene, and Godot refuses to load two resources that point at each other.
@export_file("*.tres") var default_item: String = ""

@export_group("Outline")
## Width of the grade-coloured outline, in metres (0 = none).
@export_range(0.0, 0.2, 0.001) var outline_thickness: float = 0.02

@export_group("Settling")
## Once it has landed and moves slower than this (m/s)...
@export var settle_speed: float = 0.35
## ...and spins slower than this (rad/s)...
@export var settle_spin: float = 2.0
## ...for this long (seconds), it stops completely (and sleeps until
## something pushes it again, e.g. an explosion).
@export var settle_time: float = 0.2

static var _highlight_material: StandardMaterial3D

var _meshes: Array[Node] = []
var _slow_time: float = 0.0


func _ready() -> void:
	if item == null and default_item != "":
		item = load(default_item) as InventoryItem
	_meshes = find_children("*", "MeshInstance3D", true, false)
	_add_outlines()
	# Needed to know when it has touched the ground.
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 1)


func _physics_process(delta: float) -> void:
	if global_position.y < kill_height:
		queue_free()
		return
	_settle(delta)


## Stops the pickup once it has landed and slowed down, so it never rolls away.
func _settle(delta: float) -> void:
	# Only while touching something (landed), never mid-air.
	if freeze or sleeping or get_contact_count() == 0:
		_slow_time = 0.0
		return
	if linear_velocity.length() < settle_speed and angular_velocity.length() < settle_spin:
		_slow_time += delta
		if _slow_time >= settle_time:
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			sleeping = true
			_slow_time = 0.0
	else:
		_slow_time = 0.0


## A copy of each mesh drawn as an inverted hull in the item's grade colour.
func _add_outlines() -> void:
	if outline_thickness <= 0.0 or item == null:
		return
	var color := item.get_grade_color()
	for node in _meshes:
		var source := node as MeshInstance3D
		if source.mesh == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		material.set_shader_parameter("outline_color", color)
		material.set_shader_parameter("thickness", outline_thickness)
		material.set_shader_parameter("hull_center", source.mesh.get_aabb().get_center())
		var outline := MeshInstance3D.new()
		outline.name = "Outline"
		outline.mesh = source.mesh
		outline.material_override = material
		outline.layers = source.layers
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		source.add_child(outline)


func get_interaction_text() -> String:
	var item_name := item.item_name if item else "???"
	var suffix := " (x%d)" % amount if amount > 1 else ""
	return "%s %s%s" % [verb, item_name, suffix]


func set_highlighted(on: bool) -> void:
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_highlight_material.albedo_color = Color(0.55, 0.85, 1.0, 0.22)
	for mesh in _meshes:
		(mesh as MeshInstance3D).material_overlay = _highlight_material if on else null


func interact(player: Player) -> void:
	if item == null:
		return
	var leftover := player.give_item(item, amount)
	if leftover <= 0:
		queue_free()
	else:
		amount = leftover
