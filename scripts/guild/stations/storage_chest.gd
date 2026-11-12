@tool
class_name StorageChest
extends KitPiece
## KayKit chest with its own inventory. E opens the lid and shows its
## slots above your bag in the inventory window (drag / shift+click between
## them). Contents are kept in GameState under storage_id, so they survive
## scene changes. Front (lock side) is +Z.

@export var storage_id: StringName = &"player_room_chest"
@export var title: String = "Storage Chest"
@export_range(1, 90) var slot_count: int = 27
## Width X sets the (even) scale; the rest follows the model.
@export var size: Vector3 = Vector3(1.0, 0.55, 0.6)
@export var lid_open_degrees: float = 70.0

var inventory: Inventory

var _lid: Node3D
var _tween: Tween


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	inventory = Inventory.new()
	inventory.name = "Storage"
	inventory.slot_count = slot_count
	inventory.hotbar_size = 0  # A chest has no hotbar.
	add_child(inventory)  # Not a generated node: survives rebuilds.
	inventory.from_data(GameState.get_storage(storage_id))
	inventory.slot_changed.connect(func(_i: int) -> void:
		GameState.set_storage(storage_id, inventory.to_data())
	)


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	# KayKit chest (1.7 x 1.3 x 1.45 m with its lid), scaled evenly from the
	# width; the lid is a separate part, hinged at the back top edge.
	var path := kk("chest")
	var s := size.x / 1.7
	var fit := uniform_xform(path, s, Vector3.ZERO)
	add_model_xform(path, fit, null, PackedStringArray(["chest"]))
	var body := KitPiece.model_aabb(path, PackedStringArray(["chest"]))
	add_collision_box(body.size * s, Vector3(0, body.size.y * s * 0.5, fit.origin.z + body.get_center().z * s))
	var hinge := KitPiece.model_part_xform(path, "chest_lid").origin
	_lid = Node3D.new()
	_lid.position = fit * hinge
	add_generated(_lid)
	add_model_xform(path, Transform3D(fit.basis, fit.basis * -hinge), _lid, PackedStringArray(["chest_lid"]))


func get_interaction_text() -> String:
	return "Open %s" % title.to_lower()


func interact(player: Player) -> void:
	if inventory == null:
		return
	_set_lid(true)
	player.open_storage(inventory, title.to_upper(), _set_lid.bind(false))


func _set_lid(open: bool) -> void:
	if _lid == null or not is_inside_tree():
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation_degrees:x", -lid_open_degrees if open else 0.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
