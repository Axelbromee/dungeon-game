@tool
class_name QuestBoard
extends KitPiece
## Wooden notice board with pinned notes. E shows the quest message
## (placeholder until a quest system exists). Front is +Z.

@export var width: float = 2.0
@export var board_height: float = 1.3
@export var post_height: float = 2.3
@export var title: String = "Quest Board"
@export_multiline var message: String = "Quests coming soon.\nCheck back later, adventurer."


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	var dark := mat("wood_dark")
	var board_y := post_height - board_height * 0.5 - 0.15
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.12, post_height, 0.12), Vector3(sx * (width * 0.5 - 0.06), post_height * 0.5, 0), dark)
	add_box(Vector3(width, board_height, 0.06), Vector3(0, board_y, 0.02), mat("wood"))
	add_box(Vector3(width - 0.16, board_height - 0.16, 0.02), Vector3(0, board_y, 0.055), mat("cork"), false)
	# Little roof.
	for sx in [-1.0, 1.0]:
		add_box(Vector3(width * 0.56, 0.04, 0.42), Vector3(sx * width * 0.25, post_height + 0.08, 0.02), dark, false, Vector3(0, 0, -sx * 14.0))
	# Pinned notes.
	var rng := make_rng(3)
	for i in 6:
		var note_pos := Vector3(rng.randf_range(-width * 0.38, width * 0.38), board_y + rng.randf_range(-board_height * 0.3, board_height * 0.3), 0.07)
		var note := Vector3(rng.randf_range(0.22, 0.3), rng.randf_range(0.26, 0.34), 0.005)
		add_box(note, note_pos, mat("parchment"), false, Vector3(0, 0, rng.randf_range(-8.0, 8.0)))
		add_sphere(0.012, note_pos + Vector3(0, note.y * 0.4, 0.008), mat("brass" if i % 2 else "cloth_red"))
	add_label("QUESTS", Vector3(0, post_height - 0.05, 0.08), 56)


func get_interaction_text() -> String:
	return "Read the %s" % title.to_lower()


func interact(player: Player) -> void:
	player.show_info(title, message)
