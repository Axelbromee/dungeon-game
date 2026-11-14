class_name StatsPanel
extends VBoxContainer
## "Stats" tab of the inventory window: level, XP, adventurer grade and the
## player's current values (max HP / mana / stamina, fireball damage, regen).
## Read-only.

const FONT_SIZE := 12
const HEADER_COLOR := Color(0.75, 0.9, 1.0)
const DIM_COLOR := Color(0.6, 0.68, 0.8)

var _player: Player
var _stats: PlayerStats

var _level_label: Label
var _grade_label: Label
var _xp_label: Label
var _xp_bar: ProgressBar
var _derived_label: Label


func setup(player: Player) -> void:
	_player = player
	_stats = player.stats
	add_theme_constant_override("separation", 6)
	_build()
	_stats.stats_changed.connect(refresh)
	_stats.xp_changed.connect(func(_xp: int, _next: int, _level: int) -> void: refresh())
	refresh()


func refresh() -> void:
	if _stats == null:
		return
	_level_label.text = "Level %d" % _stats.level
	_grade_label.text = "Adventurer grade %s" % _stats.grade_name()
	_xp_label.text = "XP %d / %d" % [_stats.xp, _stats.xp_to_next_level()]
	_xp_bar.max_value = _stats.xp_to_next_level()
	_xp_bar.value = _stats.xp

	var dmg := _player.fireball_base_damage * _player.fireball_damage_multiplier
	_derived_label.text = "Max HP %d    Max mana %d    Max stamina %d\nFireball damage %d    Stamina regen %.1f/s" % [
		roundi(_player.max_health), roundi(_player.max_mana), roundi(_player.max_stamina),
		roundi(dmg), _player.stamina_regen,
	]


func _build() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_level_label = _label("", 15, HEADER_COLOR)
	_grade_label = _label("", FONT_SIZE, DIM_COLOR)
	header.add_child(_level_label)
	header.add_child(_grade_label)
	add_child(header)

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	_xp_label = _label("", FONT_SIZE, DIM_COLOR)
	_xp_label.custom_minimum_size = Vector2(90, 0)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 8)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.55, 1.0)
	fill.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.09, 0.14)
	track.set_corner_radius_all(3)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	_xp_bar.add_theme_stylebox_override("background", track)
	xp_row.add_child(_xp_label)
	xp_row.add_child(_xp_bar)
	add_child(xp_row)

	add_child(HSeparator.new())
	_derived_label = _label("", 12, Color(0.85, 0.9, 0.95))
	add_child(_derived_label)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
