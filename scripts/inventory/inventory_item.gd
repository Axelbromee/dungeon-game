class_name InventoryItem
extends Resource
## Definition of an item type. Create one .tres per item (right-click in the
## FileSystem dock -> New Resource -> InventoryItem). Stacks compare items by
## resource identity, so always reference the same .tres file.

enum Grade { S, A, B, C, D, E, F }
## Used for sorting (in this order) after grade.
enum Category { SPELLBOOK, CORE, MATERIAL, PLANT, MISC }

## Colour per grade (S gold, A red-orange, B purple, C blue, D green,
## E white, F grey). Used by slots, tooltips and labels.
const GRADE_COLORS: Array[Color] = [
	Color(1.0, 0.78, 0.25),
	Color(1.0, 0.45, 0.3),
	Color(0.78, 0.5, 1.0),
	Color(0.4, 0.7, 1.0),
	Color(0.45, 0.9, 0.45),
	Color(0.88, 0.88, 0.85),
	Color(0.6, 0.6, 0.6),
]

@export var item_name: String = "Item"
## Rarity / quality tier, S (best) to F.
@export var grade: Grade = Grade.F
@export var category: Category = Category.MISC
@export_multiline var description: String = ""
## Slot icon. Unless keep_custom_icon is on, this is replaced at startup by a
## render of world_scene (see the IconBaker autoload); it's the fallback until
## that render is ready. If empty, the slot shows the first two letters.
@export var icon: Texture2D
## Keep `icon` as-is instead of generating one from the 3D model.
@export var keep_custom_icon: bool = false
@export var stackable: bool = true
@export_range(1, 999) var max_stack: int = 20
## Scene spawned when the item is dropped into the world. If the scene's root
## has `item` / `amount` / `verb` properties they are filled in automatically.
## Its meshes are also used for the generated icon and the held model.
@export var world_scene: PackedScene

@export_group("Held In Hand")
## Optional custom first-person model (e.g. an open book). If empty, the
## meshes of `world_scene` are used, without its physics/collision.
## A child Marker3D named "CastPoint" marks where spells charge from.
@export var held_scene: PackedScene
## Offset from the hand position (camera space, metres).
@export var held_offset: Vector3 = Vector3.ZERO
@export var held_rotation_degrees: Vector3 = Vector3.ZERO
@export var held_scale: float = 1.0


func get_grade_name() -> String:
	return Grade.keys()[grade]


func get_grade_color() -> Color:
	return GRADE_COLORS[clampi(grade, 0, GRADE_COLORS.size() - 1)]


func get_stack_limit() -> int:
	return max_stack if stackable else 1


func is_same_item(other: InventoryItem) -> bool:
	if other == null:
		return false
	if other == self:
		return true
	return resource_path != "" and resource_path == other.resource_path
