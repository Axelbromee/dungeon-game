class_name SpellWheelUI
extends Control
## Radial spell wheel in the middle of the screen, shown while R is held.
## The Player tracks the mouse and which slot it points at; this only draws:
## the 8 slots around a ring (slot 1 at the top, then clockwise) with their
## spells' icons, the slot under the mouse highlighted and its spell's name
## in the middle. Releasing R selects that slot (Player).

## Ring radius (to the slot centres) and slot size, in pixels.
@export var radius: float = 150.0
@export var slot_radius: float = 38.0
@export var backdrop_color: Color = Color(0.03, 0.025, 0.02, 0.6)
@export var slot_color: Color = Color(0.1, 0.08, 0.06, 0.92)
@export var border_color: Color = Color(0.45, 0.34, 0.22, 1.0)
@export var hover_color: Color = Color(1.0, 0.82, 0.45, 1.0)
## Ring marking the currently selected spell.
@export var selected_color: Color = Color(0.55, 0.85, 1.0, 1.0)

var _player: Player
var _hovered: int = -1


func setup(player: Player) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_player.spell_wheel_changed.connect(_on_wheel_changed)
	_player.spells_changed.connect(queue_redraw)


func _on_wheel_changed(open: bool, hovered_slot: int) -> void:
	visible = open
	_hovered = hovered_slot
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var centre := size * 0.5
	draw_circle(centre, radius + slot_radius + 18.0, backdrop_color)
	draw_arc(centre, radius, 0.0, TAU, 64, Color(border_color, 0.5), 2.0, true)
	var font := get_theme_default_font()
	for i in Player.SPELL_SLOTS:
		var angle := -PI * 0.5 + TAU * i / Player.SPELL_SLOTS
		var at := centre + Vector2(cos(angle), sin(angle)) * radius
		var spell: Spell = _player.equipped_spells[i]
		var hovered := i == _hovered
		var r := slot_radius * (1.15 if hovered else 1.0)
		draw_circle(at, r, slot_color.lightened(0.12) if hovered else slot_color)
		var edge := border_color
		if spell:
			edge = spell.get_grade_color()
		if hovered:
			edge = hover_color
		draw_arc(at, r, 0.0, TAU, 40, edge, 3.0 if hovered else 2.0, true)
		if i == _player.selected_spell_slot:
			draw_arc(at, r + 5.0, 0.0, TAU, 40, selected_color, 2.0, true)
		if spell and spell.icon:
			var icon_size := Vector2.ONE * r * 1.3
			draw_texture_rect(spell.icon, Rect2(at - icon_size * 0.5, icon_size), false)
		elif spell:
			_draw_centred(font, spell.spell_name.left(2).to_upper(), at, 18, spell.get_grade_color())
		_draw_centred(font, str(i + 1), at + Vector2(0, r + 12.0), 11, Color(0.7, 0.62, 0.5))

	# The pointed-at slot's spell in the middle (or the selected one).
	var shown_slot := _hovered if _hovered >= 0 else _player.selected_spell_slot
	var shown: Spell = _player.equipped_spells[shown_slot]
	var title := shown.spell_name if shown else "Empty slot"
	var color := shown.get_grade_color().lightened(0.2) if shown else Color(0.65, 0.56, 0.45)
	_draw_centred(font, title, centre + Vector2(0, -6), 20, color)
	if shown:
		_draw_centred(font, "Mana %s" % shown.get_cost_text(), centre + Vector2(0, 18), 13, Color(0.55, 0.85, 1.0))


func _draw_centred(font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := at + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
