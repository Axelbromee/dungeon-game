class_name Spell
extends Resource
## Definition of a spell. Create one .tres per spell (right-click in the
## FileSystem dock -> New Resource -> Spell). The player learns spells with
## Player.learn_spell(), equips up to 8 on the spell wheel and casts the
## selected one with the Grimoire. Spells compare by resource identity, so
## always reference the same .tres file.
##
## How a spell is cast comes from `caster` (a SpellCaster script) and the
## scene it spawns (`scene`). A new spell that works like an existing one
## (e.g. another hold-to-charge projectile) only needs a new .tres and its
## own scene; no new code.

@export var spell_name: String = "Spell"
@export_multiline var description: String = ""
## Shown in the Spell Library, on the spell wheel and next to the hotbar.
## If empty, the first two letters of the name are shown.
@export var icon: Texture2D
## Rarity / power tier, S (best) to F (same scale and colours as items).
@export var grade: InventoryItem.Grade = InventoryItem.Grade.F

@export_group("Mana")
## Mana spent on each cast; also the mana needed to start casting.
@export var mana_cost: float = 5.0

@export_group("Casting")
## Seconds LMB must be held before the spell can be cast; releasing sooner
## cancels it for free.
@export var min_charge_time: float = 0.0
## What the spell spawns (e.g. the fireball projectile).
@export var scene: PackedScene
## How the spell is cast: a script extending SpellCaster. Empty =
## ChargedProjectileCaster (hold for min_charge_time, release to fire `scene`).
@export var caster: Script


func get_grade_name() -> String:
	return InventoryItem.Grade.keys()[grade]


func get_grade_color() -> Color:
	return InventoryItem.GRADE_COLORS[clampi(grade, 0, InventoryItem.GRADE_COLORS.size() - 1)]


## The mana cost for display ("22.5", "5").
func get_cost_text() -> String:
	return String.num(mana_cost, 1).trim_suffix(".0")


## A new caster for one cast of this spell.
func create_caster() -> SpellCaster:
	var script: Script = caster if caster != null else ChargedProjectileCaster
	var instance := script.new() as SpellCaster
	if instance == null:
		push_error("Spell %s: caster must extend SpellCaster" % spell_name)
	return instance


func is_same_spell(other: Spell) -> bool:
	if other == null:
		return false
	if other == self:
		return true
	return resource_path != "" and resource_path == other.resource_path
