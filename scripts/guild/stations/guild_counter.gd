@tool
class_name GuildCounter
extends KitPiece
## Wooden counter used for the reception / rank desk and the shop. Visitors
## stand on the +Z side. E shows an info panel:
##   RECEPTION: the player's adventurer grade, level and XP.
##   SHOP: a "coming soon" message.

enum Role { RECEPTION, SHOP }

@export var role: Role = Role.RECEPTION
@export var width: float = 2.4
@export var depth: float = 0.7
@export var height: float = 1.05
@export var sign_text: String = ""


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	var dark := mat("wood_dark")
	add_box(Vector3(width, height - 0.06, depth), Vector3(0, (height - 0.06) * 0.5, 0), dark)
	add_box(Vector3(width + 0.1, 0.06, depth + 0.1), Vector3(0, height - 0.03, 0.02), mat("plank_a"), false)
	# Front panels with trim.
	var panels := maxi(int(width / 0.6), 1)
	for i in panels:
		var x := -width * 0.5 + (i + 0.5) * width / panels
		add_box(Vector3(width / panels - 0.08, height - 0.3, 0.02), Vector3(x, (height - 0.06) * 0.5, depth * 0.5 + 0.01), mat("wood"), false)
	add_box(Vector3(width + 0.04, 0.1, depth + 0.04), Vector3(0, 0.05, 0), mat("stone_wall"), false)

	var sign_label := sign_text if sign_text != "" else ("RECEPTION" if role == Role.RECEPTION else "SHOP")
	add_box(Vector3(1.1, 0.32, 0.04), Vector3(0, height + 0.95, -depth * 0.3), dark, false)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.04, 0.9, 0.04), Vector3(sx * 0.45, height + 0.45, -depth * 0.3), mat("iron"), false)
	add_label(sign_label, Vector3(0, height + 0.95, -depth * 0.3 + 0.03), 40)

	if role == Role.RECEPTION:
		_reception_props()
	else:
		_shop_props()


func _reception_props() -> void:
	var top := height
	# Brass bell (no KayKit match), an open KayKit journal as the ledger with
	# a quill, and a stack of papers.
	add_cylinder(0.07, 0.03, Vector3(width * 0.32, top + 0.015, 0.1), mat("wood_dark"), false)
	add_sphere(0.06, Vector3(width * 0.32, top + 0.06, 0.1), mat("brass"), Vector3(1, 0.8, 1))
	add_model_posed(kk("journal_open"), Vector3(-width * 0.1, top, 0.05), 0.42, Vector3(-90, 0, 0))
	add_box(Vector3(0.012, 0.012, 0.28), Vector3(-width * 0.1 + 0.15, top + 0.06, 0.02), mat("linen"), false, Vector3(25, 20, 0))
	add_model_posed(kk("blueprint_stacked"), Vector3(-width * 0.38, top, -0.05), 0.26, Vector3(0, 12, 0))


func _shop_props() -> void:
	var top := height
	var rng := make_rng(11)
	# KayKit bottles, a crate and a coin stack; the straw sack has no match.
	var bottles := ["bottle_A_green", "bottle_B_brown", "bottle_A_labeled_green", "bottle_C_brown", "bottle_A_labeled_brown"]
	for i in 5:
		add_model_sized(kk(bottles[i]), Vector3(-width * 0.4 + i * 0.12, top, 0.1), 0.18, rng.randf_range(0.0, 360.0))
	add_sphere(0.2, Vector3(width * 0.3, top + 0.16, 0.0), mat("straw"), Vector3(1.0, 0.8, 0.9))
	add_model(kk("box_small"), 0.32, Vector3(width * 0.05, top, -0.05), rng.randf_range(-15.0, 15.0))
	add_model_sized(kk("coin_stack_small"), Vector3(-width * 0.05, top, 0.15), 0.08, rng.randf_range(0.0, 360.0))


func get_interaction_text() -> String:
	return "Speak to the receptionist" if role == Role.RECEPTION else "Browse the shop"


func interact(player: Player) -> void:
	if role == Role.RECEPTION:
		var stats := player.stats
		player.show_info("Adventurer Registry",
			"Adventurer grade:  %s\nLevel %d   (XP %d / %d)\n\nRank-ups coming soon." % [
				stats.grade_name(), stats.level, stats.xp, stats.xp_to_next_level()])
	else:
		player.show_info("General Store", "The shop is coming soon.")
