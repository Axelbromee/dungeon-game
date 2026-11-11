class_name InventorySlotUI
extends Panel
## One inventory slot. Border and glow are tinted by the item's grade; the
## icon pops when an item lands here.
## Mouse:
##   drag ............ move / swap / stack (Ctrl+drag = half the stack)
##   right-click ..... split the stack in half into a free slot
##   shift+click ..... send the stack hotbar <-> bag
##   double-click .... gather every matching item into this slot
## Dropping one item is [Q] (handled by InventoryUI).

## Shift+click. InventoryUI decides where the stack goes (hotbar <-> bag, or
## chest <-> inventory while a chest is open).
signal shift_clicked(slot: InventorySlotUI)

const DRAG_TYPE := "inventory_slot"
## How strongly the grade colour tints the slot background / glow.
const GRADE_BG_TINT := 0.1
const GRADE_HOVER_TINT := 0.2
const GRADE_BORDER_ALPHA := 0.6
const GLOW_ALPHA := 0.32
const POP_SCALE := 1.28
const POP_TIME := 0.2

@export var normal_style: StyleBox
@export var hover_style: StyleBox
## Style for the active hotbar slot.
@export var selected_style: StyleBox

var index: int = -1
var inventory: Inventory
var read_only: bool = false

var _hovered: bool = false
var _selected: bool = false
var _last_item: InventoryItem = null
var _last_count: int = 0
var _has_refreshed: bool = false
var _pop_tween: Tween

## grade colour + state -> StyleBoxFlat, shared by every slot.
static var _style_cache: Dictionary = {}

@onready var _glow: TextureRect = $Glow
@onready var _icon: TextureRect = $Icon
@onready var _placeholder: Label = $Placeholder
@onready var _count: Label = $Count


func _ready() -> void:
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	resized.connect(func() -> void: _icon.pivot_offset = _icon.size * 0.5)


func setup(target_inventory: Inventory, slot_index: int, is_read_only: bool) -> void:
	inventory = target_inventory
	index = slot_index
	set_read_only(is_read_only)


## Read-only slots ignore the mouse entirely (used by the hotbar during play).
func set_read_only(value: bool) -> void:
	read_only = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
	if read_only:
		_hovered = false
	refresh()


func refresh() -> void:
	var item := inventory.get_item(index)
	var count := inventory.get_count(index)
	if item and item.icon == null:
		IconBaker.request(item)
	_icon.texture = item.icon if item else null
	_placeholder.text = item.item_name.left(2).to_upper() if item and item.icon == null else ""
	_count.text = str(count) if item and count > 1 else ""
	tooltip_text = ""  # InventoryUI draws its own tooltip.

	_glow.visible = item != null
	if item:
		var tint := item.get_grade_color()
		tint.a = GLOW_ALPHA
		_glow.modulate = tint

	# Pop when an item arrives or the stack grows (not on the first draw).
	var arrived := item != null and (not item.is_same_item(_last_item) or count > _last_count)
	if _has_refreshed and arrived:
		_pop()
	_last_item = item
	_last_count = count
	_has_refreshed = true
	_update_style()


func set_selected(on: bool) -> void:
	_selected = on
	_update_style()


func _set_hover(on: bool) -> void:
	_hovered = on
	_update_style()


func _update_style() -> void:
	var item: InventoryItem = null
	if inventory:
		item = inventory.get_item(index)
	var state := "hover" if _hovered else ("selected" if _selected else "normal")
	if item == null:
		var base: StyleBox = hover_style if _hovered else (selected_style if _selected else normal_style)
		add_theme_stylebox_override("panel", base)
		return
	add_theme_stylebox_override("panel", _graded_style(state, item.get_grade_color()))


## Base style with its border (and a little of its background) tinted.
func _graded_style(state: String, grade_color: Color) -> StyleBox:
	var key := "%s_%s" % [state, grade_color.to_html()]
	if _style_cache.has(key):
		return _style_cache[key]
	var base: StyleBox = hover_style if state == "hover" else (selected_style if state == "selected" else normal_style)
	var flat := base as StyleBoxFlat
	if flat == null:
		return base
	var style := flat.duplicate() as StyleBoxFlat
	match state:
		"hover":
			style.border_color = grade_color.lightened(0.25)
			style.bg_color = flat.bg_color.lerp(grade_color, GRADE_HOVER_TINT)
		"selected":
			style.bg_color = flat.bg_color.lerp(grade_color, GRADE_BG_TINT)  # Keep the gold border.
		_:
			var border := grade_color
			border.a = GRADE_BORDER_ALPHA
			style.border_color = flat.border_color.lerp(border, 0.85)
			style.bg_color = flat.bg_color.lerp(grade_color, GRADE_BG_TINT)
	_style_cache[key] = style
	return style


func _pop() -> void:
	if _pop_tween:
		_pop_tween.kill()
	_icon.pivot_offset = _icon.size * 0.5
	_icon.scale = Vector2.ONE * POP_SCALE
	_pop_tween = create_tween()
	_pop_tween.tween_property(_icon, "scale", Vector2.ONE, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Mouse actions ----------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if read_only:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if inventory.get_item(index) == null:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.double_click:
			inventory.gather(index)
			accept_event()
		elif mb.shift_pressed:
			shift_clicked.emit(self)
			accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		inventory.split_slot(index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if read_only or Input.is_key_pressed(KEY_SHIFT):
		return null
	var item := inventory.get_item(index)
	if item == null:
		return null
	var count := inventory.get_count(index)
	var amount := count
	if Input.is_key_pressed(KEY_CTRL) and count >= 2:
		amount = count / 2  # Ctrl+drag: carry half.
	set_drag_preview(_make_preview(item, amount))
	if amount == count:
		_icon.modulate.a = 0.35
	return {"type": DRAG_TYPE, "from": index, "amount": amount, "inventory": inventory}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if read_only or not (data is Dictionary) or data.get("type") != DRAG_TYPE:
		return false
	return Inventory.can_transfer(_source_of(data), int(data["from"]), inventory, index, int(data.get("amount", -1)))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Inventory.transfer(_source_of(data), int(data["from"]), inventory, index, int(data.get("amount", -1)))


func _source_of(data: Dictionary) -> Inventory:
	var source := data.get("inventory") as Inventory
	return source if is_instance_valid(source) else inventory


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_node_ready():
		_icon.modulate.a = 1.0


func _make_preview(item: InventoryItem, amount: int) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.icon:
		var tex := TextureRect.new()
		tex.texture = item.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size = Vector2(48, 48)
		tex.position = Vector2(-24, -24)
		holder.add_child(tex)
	var label := Label.new()
	label.text = (str(amount) if amount > 1 else "") if item.icon else item.item_name.left(2).to_upper()
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(8, 6) if item.icon else Vector2(-12, -12)
	holder.add_child(label)
	return holder
