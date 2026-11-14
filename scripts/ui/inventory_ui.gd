class_name InventoryUI
extends Control
## Toggleable inventory window (the bag) + the always-visible hotbar, and an
## optional storage section (an open chest) above the bag. Tabs: Items,
## Stats and Spells (the Spell Library). While the Grimoire is held, the
## selected spell is shown next to the hotbar.
## Inventory slots [0, hotbar_size) are the hotbar, shown only in the bar at
## the bottom of the screen; the rest are the bag, shown in the window. While
## the window is open the hotbar accepts drags too. The Player owns which
## hotbar slot is active (mouse wheel / number keys) and this UI highlights it.
## Emits open_changed so the HUD/Player can free or capture the mouse.

signal open_changed(is_open: bool)

@export var slot_scene: PackedScene
## Tooltip distance from the mouse cursor (px).
@export var tooltip_offset: Vector2 = Vector2(18, 18)

const CATEGORY_NAMES := ["Spellbook", "Magic core", "Material", "Plant", "Item"]

var is_open: bool = false

var _player: Player
var _inventory: Inventory
## Inventory index -> its slot view (bag views in the window, hotbar views
## in the bar). Every inventory index has exactly one view.
var _views: Dictionary = {}
var _hotbar_slots: Array[InventorySlotUI] = []
var _hover_inventory: Inventory = null
var _hover_index: int = -1
var _tooltip_style: StyleBoxFlat
var _badge_style: StyleBoxFlat

var _storage: Inventory = null
var _storage_views: Dictionary = {}
var _storage_on_close: Callable = Callable()

@onready var _drop_zone: InventoryDropZone = $DropZone
@onready var _window: Control = $Window
@onready var _grid: GridContainer = $Window/Margin/VBox/ItemsPage/Grid
@onready var _items_page: Control = $Window/Margin/VBox/ItemsPage
@onready var _storage_section: Control = $Window/Margin/VBox/ItemsPage/StorageSection
@onready var _storage_title: Label = $Window/Margin/VBox/ItemsPage/StorageSection/StorageTitle
@onready var _storage_grid: GridContainer = $Window/Margin/VBox/ItemsPage/StorageSection/StorageGrid
@onready var _sort_button: Button = $Window/Margin/VBox/ItemsPage/Toolbar/SortButton
@onready var _stats_page: StatsPanel = $Window/Margin/VBox/StatsPage
@onready var _items_tab: Button = $Window/Margin/VBox/Tabs/ItemsTab
@onready var _stats_tab: Button = $Window/Margin/VBox/Tabs/StatsTab
@onready var _spells_page: SpellLibraryUI = $Window/Margin/VBox/SpellsPage
@onready var _spells_tab: Button = $Window/Margin/VBox/Tabs/SpellsTab
@onready var _spell_indicator: Control = $SpellIndicator
@onready var _spell_icon: TextureRect = $SpellIndicator/Icon
@onready var _spell_name: Label = $SpellIndicator/Name
@onready var _hotbar: HBoxContainer = $Hotbar
@onready var _selected_label: Label = $SelectedLabel
@onready var _tooltip: PanelContainer = $Tooltip
@onready var _tooltip_name: Label = $Tooltip/Margin/VBox/Name
@onready var _tooltip_badge: PanelContainer = $Tooltip/Margin/VBox/BadgeRow/Badge
@onready var _tooltip_badge_label: Label = $Tooltip/Margin/VBox/BadgeRow/Badge/Letter
@onready var _tooltip_info: Label = $Tooltip/Margin/VBox/BadgeRow/Info
@onready var _tooltip_desc: Label = $Tooltip/Margin/VBox/Description
@onready var _tooltip_stack: Label = $Tooltip/Margin/VBox/Stack


func setup(player: Player) -> void:
	_player = player
	_inventory = player.inventory
	var hotbar_count := mini(player.hotbar_size, _inventory.slot_count)
	# Same width as the hotbar so the window and the bar line up.
	_grid.columns = maxi(hotbar_count, 1)
	_storage_grid.columns = _grid.columns

	for i in hotbar_count:
		var hotbar_slot := _make_slot(_hotbar, _inventory, i, true)
		_hotbar_slots.append(hotbar_slot)
		_views[i] = hotbar_slot
	for i in range(hotbar_count, _inventory.slot_count):
		_views[i] = _make_slot(_grid, _inventory, i, false)

	_stats_page.setup(player)
	_spells_page.setup(player)
	var tab_group := ButtonGroup.new()
	_items_tab.button_group = tab_group
	_stats_tab.button_group = tab_group
	_spells_tab.button_group = tab_group
	_items_tab.pressed.connect(_show_page.bind(Page.ITEMS))
	_stats_tab.pressed.connect(_show_page.bind(Page.STATS))
	_spells_tab.pressed.connect(_show_page.bind(Page.SPELLS))
	_sort_button.pressed.connect(_inventory.sort_bag)

	_tooltip_style = (_tooltip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_tooltip.add_theme_stylebox_override("panel", _tooltip_style)
	_badge_style = (_tooltip_badge.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_tooltip_badge.add_theme_stylebox_override("panel", _badge_style)

	_inventory.slot_changed.connect(_on_slot_changed)
	_player.hotbar_selection_changed.connect(_on_selection_changed)
	_player.selected_spell_changed.connect(func(_spell: Spell) -> void: _update_spell_indicator())
	_player.spells_changed.connect(_update_spell_indicator)
	_drop_zone.dropped_outside.connect(func(source: Inventory, from_index: int, amount: int) -> void:
		var inv := source if is_instance_valid(source) else _inventory
		_drop(inv, from_index, inv.get_count(from_index) if amount <= 0 else amount)
	)
	IconBaker.icon_ready.connect(_on_icon_ready)
	_storage_section.visible = false
	_apply_open(false)
	_on_selection_changed(_player.selected_hotbar_index)


func set_open(open: bool) -> void:
	if open == is_open or _inventory == null:
		return
	is_open = open
	_apply_open(open)
	open_changed.emit(open)


## Opens the window with `storage` shown above the bag (a chest).
func open_storage(storage: Inventory, title: String, on_close: Callable = Callable()) -> void:
	if storage == null:
		return
	_close_storage()
	_storage = storage
	_storage_on_close = on_close
	_storage_title.text = title
	for i in storage.slot_count:
		_storage_views[i] = _make_slot(_storage_grid, storage, i, false)
	storage.slot_changed.connect(_on_storage_slot_changed)
	_storage_section.visible = true
	_items_tab.button_pressed = true
	_show_page(Page.ITEMS)
	if is_open:
		_update_tooltip()
	else:
		set_open(true)


func _unhandled_input(event: InputEvent) -> void:
	if _inventory == null:
		return
	if event.is_action_pressed("inventory"):
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("drop_item") and _hover_inventory != null:
		_drop(_hover_inventory, _hover_index, 1)
		get_viewport().set_input_as_handled()


func _make_slot(parent: Control, inv: Inventory, index: int, read_only: bool) -> InventorySlotUI:
	var slot := slot_scene.instantiate() as InventorySlotUI
	parent.add_child(slot)
	slot.setup(inv, index, read_only)
	slot.mouse_entered.connect(_set_hovered.bind(inv, index))
	slot.mouse_exited.connect(_clear_hovered.bind(inv, index))
	slot.shift_clicked.connect(_on_shift_clicked)
	return slot


func _apply_open(open: bool) -> void:
	_window.visible = open
	_drop_zone.visible = open
	_hover_inventory = null
	_hover_index = -1
	_update_tooltip()
	if not open:
		_close_storage()
		_spells_page.clear_pick()
	# Hotbar is display-only while playing, drag-and-drop-able while open.
	for slot in _hotbar_slots:
		slot.set_read_only(not open)


func _close_storage() -> void:
	if _storage == null:
		return
	if _storage.slot_changed.is_connected(_on_storage_slot_changed):
		_storage.slot_changed.disconnect(_on_storage_slot_changed)
	for view in _storage_views.values():
		(view as Node).queue_free()
	_storage_views.clear()
	_storage = null
	_storage_section.visible = false
	if _storage_on_close.is_valid():
		_storage_on_close.call()
	_storage_on_close = Callable()


enum Page { ITEMS, STATS, SPELLS }


func _show_page(page: Page) -> void:
	_items_page.visible = page == Page.ITEMS
	_stats_page.visible = page == Page.STATS
	_spells_page.visible = page == Page.SPELLS
	if page == Page.STATS:
		_stats_page.refresh()
	elif page == Page.SPELLS:
		_spells_page.refresh()
	_hover_inventory = null
	_hover_index = -1
	_update_tooltip()


## Shift+click: chest <-> inventory while a chest is open, else hotbar <-> bag.
func _on_shift_clicked(slot: InventorySlotUI) -> void:
	if _storage != null:
		if slot.inventory == _storage:
			Inventory.send_stack(_storage, slot.index, _inventory)
		else:
			Inventory.send_stack(_inventory, slot.index, _storage)
	else:
		slot.inventory.quick_move(slot.index)


func _drop(inv: Inventory, index: int, amount: int) -> void:
	if amount <= 0 or inv == null:
		return
	if inv == _inventory:
		_player.drop_from_slot(index, amount)
		return
	var item := inv.get_item(index)
	if item == null or item.world_scene == null:
		return
	_player.drop_item_stack(item, inv.remove_from_slot(index, amount))


func _on_slot_changed(index: int) -> void:
	if _views.has(index):
		(_views[index] as InventorySlotUI).refresh()
	if index == _player.selected_hotbar_index:
		_update_selected_label()
		_update_spell_indicator()
	if _hover_inventory == _inventory and index == _hover_index:
		_update_tooltip()  # Item moved/dropped/stacked under the cursor.


func _on_storage_slot_changed(index: int) -> void:
	if _storage_views.has(index):
		(_storage_views[index] as InventorySlotUI).refresh()
	if _hover_inventory == _storage and index == _hover_index:
		_update_tooltip()


## A freshly baked icon: redraw every slot showing that item.
func _on_icon_ready(item: InventoryItem) -> void:
	for i in _views:
		if item.is_same_item(_inventory.get_item(i)):
			(_views[i] as InventorySlotUI).refresh()
	if _storage != null:
		for i in _storage_views:
			if item.is_same_item(_storage.get_item(i)):
				(_storage_views[i] as InventorySlotUI).refresh()


# --- Tooltip ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _tooltip.visible:
		return
	if get_viewport().gui_is_dragging():
		_tooltip.visible = false
		return
	_place_tooltip()


func _set_hovered(inv: Inventory, index: int) -> void:
	_hover_inventory = inv
	_hover_index = index
	_update_tooltip()


func _clear_hovered(inv: Inventory, index: int) -> void:
	if _hover_inventory == inv and _hover_index == index:
		_hover_inventory = null
		_hover_index = -1
		_update_tooltip()


func _update_tooltip() -> void:
	var item: InventoryItem = null
	if is_instance_valid(_hover_inventory) and _hover_index >= 0:
		item = _hover_inventory.get_item(_hover_index)
	if item == null or not is_open:
		_tooltip.visible = false
		return
	var color := item.get_grade_color()
	_tooltip_name.text = item.item_name
	_tooltip_name.add_theme_color_override("font_color", color)
	_badge_style.bg_color = color
	_tooltip_badge_label.text = item.get_grade_name()
	_tooltip_info.text = "Grade %s  ·  %s" % [item.get_grade_name(), CATEGORY_NAMES[clampi(item.category, 0, CATEGORY_NAMES.size() - 1)]]
	_tooltip_desc.text = item.description
	_tooltip_desc.visible = item.description != ""
	var count := _hover_inventory.get_count(_hover_index)
	_tooltip_stack.text = "Stack %d / %d" % [count, item.get_stack_limit()] if item.stackable else "Unique"
	var border := color
	border.a = 0.8
	_tooltip_style.border_color = border
	_tooltip.reset_size()
	_tooltip.visible = true
	_place_tooltip()


## Follow the mouse, flipping to the other side near the screen edges.
func _place_tooltip() -> void:
	var mouse := get_global_mouse_position()
	var screen := get_viewport_rect().size
	var tip_size := _tooltip.size
	var pos := mouse + tooltip_offset
	if pos.x + tip_size.x > screen.x:
		pos.x = mouse.x - tooltip_offset.x - tip_size.x
	if pos.y + tip_size.y > screen.y:
		pos.y = mouse.y - tooltip_offset.y - tip_size.y
	_tooltip.global_position = pos.max(Vector2.ZERO)


func _on_selection_changed(index: int) -> void:
	for i in _hotbar_slots.size():
		_hotbar_slots[i].set_selected(i == index)
	_update_selected_label()
	_update_spell_indicator()


## The selected spell's icon and name next to the hotbar, while the
## Grimoire is held.
func _update_spell_indicator() -> void:
	var spell := _player.get_selected_spell()
	_spell_indicator.visible = _player.is_holding_grimoire()
	_spell_icon.texture = spell.icon if spell else null
	_spell_name.text = spell.spell_name if spell else "No spell selected"
	_spell_name.add_theme_color_override("font_color", spell.get_grade_color().lightened(0.2) if spell else Color(0.65, 0.56, 0.45))


func _update_selected_label() -> void:
	var item := _player.get_selected_item()
	_selected_label.text = item.item_name if item else ""
	if item:
		_selected_label.add_theme_color_override("font_color", item.get_grade_color().lightened(0.2))
