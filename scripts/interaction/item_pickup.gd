class_name ItemPickup
extends RigidBody3D
## A physical item lying in the world (what you get when dropping from the
## inventory). Tumbles and bounces, and can be picked up with the interact
## key. Lives on physics layer 3 ("interactable") and collides with the world.

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

static var _highlight_material: StandardMaterial3D

var _meshes: Array[Node] = []


func _ready() -> void:
	if item == null and default_item != "":
		item = load(default_item) as InventoryItem
	_meshes = find_children("*", "MeshInstance3D", true, false)


func _physics_process(_delta: float) -> void:
	if global_position.y < kill_height:
		queue_free()


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
