@tool
class_name StorageChest
extends KitPiece
## Fantasy Props chest (Chest_Wood) with its own inventory. E opens the lid and shows its
## slots above your bag in the inventory window (drag / shift+click between
## them). Contents are kept in GameState under storage_id, so they survive
## scene changes. Front (lock side) is +Z.

@export var storage_id: StringName = &"player_room_chest"
@export var title: String = "Storage Chest"
@export_range(1, 90) var slot_count: int = 27
## Width X sets the (even) scale; the rest follows the model.
@export var size: Vector3 = Vector3(1.0, 0.55, 0.6)
@export var lid_open_degrees: float = 70.0

const BASE_PART := "Chest_Wood_Base"
const LID_PART := "Chest_Wood_Lid"
## The lid's hinge in model space (Chest_Wood's Chest_Top bone).
const LID_HINGE := Vector3(0.0, 0.429, -0.314)

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
	# Chest_Wood (1.28 x 0.72 x 0.76 m with its lid), scaled evenly from the
	# width; the lid is a separate part, hinged at the back top edge (the
	# model's Chest_Top bone).
	var path := fp("Chest_Wood")
	var src := KitPiece.model_aabb(path)
	var s := size.x / src.size.x
	var fit := uniform_xform(path, s, Vector3.ZERO)
	add_model_xform(path, fit, null, PackedStringArray([BASE_PART]))
	var body := KitPiece.model_aabb(path, PackedStringArray([BASE_PART]))
	add_collision_box(body.size * s, Vector3(0, body.size.y * s * 0.5, fit.origin.z + body.get_center().z * s))
	_lid = Node3D.new()
	_lid.position = fit * LID_HINGE
	add_generated(_lid)
	add_model_xform(path, Transform3D(fit.basis, fit.basis * -LID_HINGE), _lid, PackedStringArray([LID_PART]))


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
