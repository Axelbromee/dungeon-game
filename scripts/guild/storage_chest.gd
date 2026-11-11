@tool
class_name StorageChest
extends KitPiece
## Iron-banded chest with its own inventory. E opens the lid and shows its
## slots above your bag in the inventory window (drag / shift+click between
## them). Contents are kept in GameState under storage_id, so they survive
## scene changes. Front (lock side) is +Z.

@export var storage_id: StringName = &"player_room_chest"
@export var title: String = "Storage Chest"
@export_range(1, 90) var slot_count: int = 27
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
	var body_h := size.y * 0.72
	var lid_h := size.y - body_h
	var wood := mat("plank_b")
	var iron := mat("iron")
	add_box(Vector3(size.x, body_h, size.z), Vector3(0, body_h * 0.5, 0), wood, false)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.05, body_h + 0.01, size.z + 0.02), Vector3(sx * size.x * 0.32, body_h * 0.5, 0), iron, false)
	add_box(Vector3(size.x + 0.02, 0.05, size.z + 0.02), Vector3(0, 0.04, 0), iron, false)
	add_collision_box(size, Vector3(0, size.y * 0.5, 0))

	# Lid hinged at the back top edge.
	_lid = Node3D.new()
	_lid.position = Vector3(0, body_h, -size.z * 0.5)
	add_generated(_lid)
	add_box(Vector3(size.x + 0.02, lid_h, size.z + 0.02), Vector3(0, lid_h * 0.5, size.z * 0.5), mat("plank_a"), false, Vector3.ZERO, _lid)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.05, lid_h + 0.02, size.z + 0.04), Vector3(sx * size.x * 0.32, lid_h * 0.5, size.z * 0.5), iron, false, Vector3.ZERO, _lid)
	add_box(Vector3(0.12, 0.14, 0.03), Vector3(0, -0.02, size.z + 0.02), mat("brass"), false, Vector3.ZERO, _lid)


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
