class_name InventoryDropZone
extends ColorRect
## Full-screen backdrop behind the inventory window. A slot dragged here
## (i.e. outside the window) is dropped into the 3D world: the whole stack,
## or half with Ctrl+drag. Works for the bag, hotbar and open chests.

signal dropped_outside(source: Inventory, from_index: int, amount: int)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == InventorySlotUI.DRAG_TYPE


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped_outside.emit(data.get("inventory") as Inventory, int(data["from"]), int(data.get("amount", -1)))
