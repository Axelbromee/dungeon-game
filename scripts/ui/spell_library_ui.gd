class_name SpellLibraryUI
extends VBoxContainer
## "Spells" tab of the inventory window: the spell wheel's 8 slots and every
## learned spell (icon, name, grade, mana cost, description).
## Equip: drag a spell onto a wheel slot, or click the spell and then a slot.
## Dragging a wheel slot onto another swaps them; dragging it onto the list
## or right-clicking it unequips it.

const DRAG_TYPE := "spell"
const FONT_SIZE := 12
const HEADER_COLOR := Color(0.85, 0.72, 0.5)
const DIM_COLOR := Color(0.65, 0.56, 0.45)
const TEXT_COLOR := Color(0.82, 0.78, 0.72)
const SLOT_SIZE := Vector2(46, 46)
const ROW_ICON_SIZE := Vector2(40, 40)

var _player: Player
## The spell clicked in the list, waiting for a slot click (null = none).
var _picked: Spell = null
var _slots: Array[WheelSlot] = []
var _list: VBoxContainer
var _empty_label: Label
var _rows: Array[SpellRow] = []


func setup(player: Player) -> void:
	_player = player
	_build()
	_player.spells_changed.connect(refresh)
	_player.selected_spell_changed.connect(func(_spell: Spell) -> void: refresh())
	refresh()


func refresh() -> void:
	if _player == null:
		return
	if _picked != null and not _player.knows_spell(_picked):
		_picked = null
	for i in _slots.size():
		_slots[i].show_spell(_player.equipped_spells[i], i == _player.selected_spell_slot)
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for spell in _player.learned_spells:
		var row := SpellRow.new(self, spell)
		_list.add_child(row)
		_rows.append(row)
	_empty_label.visible = _player.learned_spells.is_empty()
	_update_picked()


## Called when the window closes: forget a half-done click-to-equip.
func clear_pick() -> void:
	_picked = null
	_update_picked()


func _build() -> void:
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(440, 0)

	add_child(_label("SPELL WHEEL", 11, DIM_COLOR))
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 6)
	add_child(slot_row)
	for i in Player.SPELL_SLOTS:
		var slot := WheelSlot.new(self, i)
		slot_row.add_child(slot)
		_slots.append(slot)

	add_child(HSeparator.new())
	add_child(_label("LEARNED SPELLS", 11, DIM_COLOR))
	var scroll := ListScroll.new(self)
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS  # Drops on empty list space reach the scroll.
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_empty_label = _label("No spells learned yet.", FONT_SIZE, DIM_COLOR)
	_list.add_child(_empty_label)

	var hint := _label("Drag a spell onto a wheel slot, or click it and then a slot   ·   Drag slots to swap\nRight-click a slot or drag it back to the list: unequip   ·   Hold [R] in play: spell wheel", 10, Color(0.6, 0.53, 0.44))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _update_picked() -> void:
	for row in _rows:
		row.set_picked(_picked != null and row.spell.is_same_spell(_picked))
	for slot in _slots:
		slot.set_waiting(_picked != null)


# --- Actions from the rows and slots ------------------------------------------

func _on_row_clicked(spell: Spell) -> void:
	_picked = null if spell.is_same_spell(_picked) else spell
	_update_picked()


func _on_slot_clicked(index: int) -> void:
	if _picked != null:
		_player.equip_spell(_picked, index)
		_picked = null
		_update_picked()


func _on_slot_dropped(index: int, data: Dictionary) -> void:
	if data.has("from_slot"):
		_player.swap_spell_slots(int(data["from_slot"]), index)
	else:
		_player.equip_spell(data["spell"] as Spell, index)
	_picked = null
	_update_picked()


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Icon (or the first two letters of the name) for `spell`.
static func make_icon(spell: Spell, icon_size: Vector2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = icon_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if spell == null:
		return holder
	if spell.icon:
		var rect := TextureRect.new()
		rect.texture = spell.icon
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	else:
		var letters := _label(spell.spell_name.left(2).to_upper(), 14, spell.get_grade_color())
		letters.set_anchors_preset(Control.PRESET_FULL_RECT)
		letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(letters)
	return holder


static func _panel_style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


# --- Wheel slot ---------------------------------------------------------------

class WheelSlot extends Panel:
	var library: SpellLibraryUI
	var index: int
	var spell: Spell = null
	var _selected: bool = false
	var _waiting: bool = false
	var _hovered: bool = false
	var _icon_holder: Control
	var _number: Label

	func _init(owner_library: SpellLibraryUI, slot_index: int) -> void:
		library = owner_library
		index = slot_index
		custom_minimum_size = SpellLibraryUI.SLOT_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP
		_number = SpellLibraryUI._label(str(slot_index + 1), 9, SpellLibraryUI.DIM_COLOR)
		_number.position = Vector2(4, 1)
		add_child(_number)
		mouse_entered.connect(_set_hovered.bind(true))
		mouse_exited.connect(_set_hovered.bind(false))

	func show_spell(new_spell: Spell, selected: bool) -> void:
		spell = new_spell
		_selected = selected
		if _icon_holder:
			_icon_holder.queue_free()
		_icon_holder = SpellLibraryUI.make_icon(spell, SpellLibraryUI.SLOT_SIZE - Vector2(10, 10))
		_icon_holder.position = Vector2(5, 5)
		add_child(_icon_holder)
		move_child(_number, -1)
		tooltip_text = "%s  (slot %d)" % [spell.spell_name, index + 1] if spell else "Empty slot %d" % (index + 1)
		_update_style()

	func set_waiting(on: bool) -> void:
		_waiting = on
		_update_style()

	func _set_hovered(on: bool) -> void:
		_hovered = on
		_update_style()

	func _update_style() -> void:
		var border := Color(0.38, 0.28, 0.18)
		if spell:
			border = spell.get_grade_color()
			border.a = 0.7
		if _selected:
			border = Color(1.0, 0.82, 0.45)
		if _hovered or _waiting:
			border = border.lightened(0.35)
		var bg := Color(0.12, 0.095, 0.07) if not _hovered else Color(0.17, 0.13, 0.09)
		add_theme_stylebox_override("panel", SpellLibraryUI._panel_style(bg, border, 2 if _selected or _waiting else 1))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			library._on_slot_clicked(index)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			library._player.unequip_spell_slot(index)
			accept_event()

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if spell == null:
			return null
		set_drag_preview(SpellLibraryUI.make_icon(spell, SpellLibraryUI.SLOT_SIZE))
		return {"type": SpellLibraryUI.DRAG_TYPE, "spell": spell, "from_slot": index}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("type") == SpellLibraryUI.DRAG_TYPE

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		library._on_slot_dropped(index, data)


# --- Learned spell row ----------------------------------------------------------

class SpellRow extends PanelContainer:
	var library: SpellLibraryUI
	var spell: Spell
	var _picked: bool = false
	var _hovered: bool = false

	func _init(owner_library: SpellLibraryUI, row_spell: Spell) -> void:
		library = owner_library
		spell = row_spell
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hbox)
		hbox.add_child(SpellLibraryUI.make_icon(spell, SpellLibraryUI.ROW_ICON_SIZE))

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_constant_override("separation", 2)
		hbox.add_child(text)

		var title := HBoxContainer.new()
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_constant_override("separation", 8)
		text.add_child(title)
		var name_label := SpellLibraryUI._label(spell.spell_name, 14, spell.get_grade_color())
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		name_label.add_theme_constant_override("outline_size", 3)
		title.add_child(name_label)
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style := SpellLibraryUI._panel_style(spell.get_grade_color(), spell.get_grade_color(), 0)
		badge_style.content_margin_top = 0
		badge_style.content_margin_bottom = 0
		badge_style.set_corner_radius_all(4)
		badge.add_theme_stylebox_override("panel", badge_style)
		badge.add_child(SpellLibraryUI._label(spell.get_grade_name(), 11, Color(0.06, 0.05, 0.04)))
		title.add_child(badge)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(spacer)
		title.add_child(SpellLibraryUI._label("Mana %s" % spell.get_cost_text(), SpellLibraryUI.FONT_SIZE, Color(0.55, 0.85, 1.0)))

		var desc := SpellLibraryUI._label(spell.description, SpellLibraryUI.FONT_SIZE, SpellLibraryUI.TEXT_COLOR)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(300, 0)
		desc.visible = spell.description != ""
		text.add_child(desc)

		mouse_entered.connect(_set_hovered.bind(true))
		mouse_exited.connect(_set_hovered.bind(false))
		_update_style()

	func set_picked(on: bool) -> void:
		_picked = on
		_update_style()

	func _set_hovered(on: bool) -> void:
		_hovered = on
		_update_style()

	func _update_style() -> void:
		var border := Color(0.3, 0.22, 0.14)
		if _picked:
			border = Color(1.0, 0.82, 0.45)
		elif _hovered:
			border = spell.get_grade_color().lightened(0.2)
		var bg := Color(0.11, 0.088, 0.066) if not _hovered else Color(0.15, 0.115, 0.085)
		add_theme_stylebox_override("panel", SpellLibraryUI._panel_style(bg, border, 2 if _picked else 1))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			library._on_row_clicked(spell)
			accept_event()

	func _get_drag_data(_at_position: Vector2) -> Variant:
		set_drag_preview(SpellLibraryUI.make_icon(spell, SpellLibraryUI.SLOT_SIZE))
		return {"type": SpellLibraryUI.DRAG_TYPE, "spell": spell}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("type") == SpellLibraryUI.DRAG_TYPE and data.has("from_slot")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		library._player.unequip_spell_slot(int(data["from_slot"]))


# --- List area: dropping a wheel slot anywhere on it unequips -----------------

class ListScroll extends ScrollContainer:
	var library: SpellLibraryUI

	func _init(owner_library: SpellLibraryUI) -> void:
		library = owner_library

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("type") == SpellLibraryUI.DRAG_TYPE and data.has("from_slot")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		library._player.unequip_spell_slot(int(data["from_slot"]))
