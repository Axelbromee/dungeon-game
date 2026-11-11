class_name Harvestable
extends Area3D
## World pickup / forageable. The Player's interaction ray finds this Area3D
## (physics layer 3, "interactable") and calls interact().

@export var item: InventoryItem
@export_range(1, 999) var amount: int = 1
## Verb shown in the prompt, e.g. "Harvest" or "Pick up".
@export var verb: String = "Harvest"

@export_group("Glow")
## MeshInstance3D whose material_override glows and brightens when targeted.
@export var glow_mesh: MeshInstance3D
@export var base_glow: float = 2.5
@export var highlight_glow: float = 7.0
@export var pulse_speed: float = 1.2

var _glow_material: StandardMaterial3D
var _highlighted: bool = false
var _t: float = 0.0


func _ready() -> void:
	_t = randf() * 10.0
	if glow_mesh and glow_mesh.material_override is StandardMaterial3D:
		# Own copy so highlighting one plant doesn't light up all of them.
		_glow_material = glow_mesh.material_override.duplicate()
		glow_mesh.material_override = _glow_material


func _process(delta: float) -> void:
	if _glow_material == null:
		return
	_t += delta
	var target := highlight_glow if _highlighted else base_glow
	var pulse := 0.85 + 0.15 * sin(_t * pulse_speed * TAU)
	_glow_material.emission_energy_multiplier = target * pulse


func get_interaction_text() -> String:
	var item_name := item.item_name if item else "???"
	var suffix := " (x%d)" % amount if amount > 1 else ""
	return "%s %s%s" % [verb, item_name, suffix]


func set_highlighted(on: bool) -> void:
	_highlighted = on


func interact(player: Player) -> void:
	if item == null:
		return
	var leftover := player.give_item(item, amount)
	if leftover <= 0:
		queue_free()
	else:
		amount = leftover  # Inventory full: leave the rest in the world.
