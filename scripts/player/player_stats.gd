class_name PlayerStats
extends Node
## Level, XP, stats and adventurer grade. Pure data: the Player turns the
## stats into max HP / mana / stamina, stamina regen, move speed and fireball
## damage (see the bonus functions below). Stats are changed with set_stat().

signal xp_changed(xp: int, xp_to_next: int, level: int)
signal leveled_up(level: int)
## Any stat, level or grade change.
signal stats_changed

enum Stat { VITALITY, MAGIC, ENDURANCE, AGILITY }

@export_group("Leveling")
## XP needed to go from level 1 to 2.
@export var xp_for_level_2: int = 100
## Each level needs this many times more XP than the previous one.
@export var xp_growth: float = 1.35

@export_group("Per Point")
@export var vitality_health_per_point: float = 10.0
@export var magic_mana_per_point: float = 8.0
## Fireball damage bonus per Magic point (0.05 = +5 %).
@export var magic_damage_per_point: float = 0.05
@export var endurance_stamina_per_point: float = 8.0
@export var endurance_regen_per_point: float = 1.5
## Move speed bonus per Agility point (0.03 = +3 %).
@export var agility_speed_per_point: float = 0.03

var level: int = 1
var xp: int = 0
## Not upgradable yet; shown on the Stats tab.
var adventurer_grade: InventoryItem.Grade = InventoryItem.Grade.F

var _values: Dictionary = {
	Stat.VITALITY: 0,
	Stat.MAGIC: 0,
	Stat.ENDURANCE: 0,
	Stat.AGILITY: 0,
}


func xp_to_next_level() -> int:
	return maxi(roundi(xp_for_level_2 * pow(xp_growth, level - 1)), 1)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		leveled_up.emit(level)
		stats_changed.emit()
	xp_changed.emit(xp, xp_to_next_level(), level)


func get_stat(stat: Stat) -> int:
	return int(_values.get(stat, 0))


## Sets a stat directly (for future systems: gear, quests, grades...).
func set_stat(stat: Stat, value: int) -> void:
	value = maxi(value, 0)
	if value == get_stat(stat):
		return
	_values[stat] = value
	stats_changed.emit()


func to_data() -> Dictionary:
	var values := {}
	for stat in _values:
		values[int(stat)] = _values[stat]
	return {"level": level, "xp": xp, "grade": int(adventurer_grade), "values": values}


func from_data(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	adventurer_grade = int(data.get("grade", InventoryItem.Grade.F)) as InventoryItem.Grade
	var values: Dictionary = data.get("values", {})
	for stat in values:
		_values[int(stat)] = int(values[stat])
	stats_changed.emit()
	xp_changed.emit(xp, xp_to_next_level(), level)


func grade_name() -> String:
	return InventoryItem.Grade.keys()[adventurer_grade]


static func stat_name(stat: Stat) -> String:
	return (Stat.keys()[stat] as String).capitalize()


func stat_effect_text(stat: Stat) -> String:
	match stat:
		Stat.VITALITY:
			return "+%d max HP" % roundi(vitality_health_per_point)
		Stat.MAGIC:
			return "+%d%% fireball damage, +%d max mana" % [roundi(magic_damage_per_point * 100.0), roundi(magic_mana_per_point)]
		Stat.ENDURANCE:
			return "+%d max stamina, +%.1f/s regen" % [roundi(endurance_stamina_per_point), endurance_regen_per_point]
		Stat.AGILITY:
			return "+%d%% move speed" % roundi(agility_speed_per_point * 100.0)
	return ""


# --- Bonuses (used by the Player) ------------------------------------------

func health_bonus() -> float:
	return get_stat(Stat.VITALITY) * vitality_health_per_point


func mana_bonus() -> float:
	return get_stat(Stat.MAGIC) * magic_mana_per_point


func fireball_damage_bonus() -> float:
	return get_stat(Stat.MAGIC) * magic_damage_per_point


func stamina_bonus() -> float:
	return get_stat(Stat.ENDURANCE) * endurance_stamina_per_point


func stamina_regen_bonus() -> float:
	return get_stat(Stat.ENDURANCE) * endurance_regen_per_point


func speed_bonus() -> float:
	return get_stat(Stat.AGILITY) * agility_speed_per_point
