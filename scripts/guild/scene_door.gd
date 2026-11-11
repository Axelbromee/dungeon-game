@tool
class_name SceneDoor
extends KitWall
## A doorway wall segment with a closed door and a sign; E takes the player
## to another scene (fade, keep inventory/stats, arrive at a SpawnPoint).
## Used for the player room door and the way back from the dungeon.

@export_group("Destination")
@export_file("*.tscn") var target_scene: String = ""
## spawn_id of the SpawnPoint to arrive at in the target scene.
@export var target_spawn: StringName = &"default"
@export var prompt: String = "Enter"
@export var sign_text: String = ""


func _build() -> void:
	style = Style.DOORWAY
	super._build()
	# Closed door leaf (its own body so it's targetable).
	var leaf := StaticBody3D.new()
	leaf.collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	add_generated(leaf)
	var w := door_width - 0.06
	var h := door_height - 0.04
	var mats := ["plank_a", "plank_b", "plank_c"]
	for i in 5:
		add_box(Vector3(w / 5.0 - 0.01, h, 0.07), Vector3(-w * 0.5 + (i + 0.5) * w / 5.0, h * 0.5, 0), mat(mats[i % 3]), false, Vector3.ZERO, leaf)
	add_collision_box(Vector3(w, h, 0.08), Vector3(0, h * 0.5, 0), Vector3.ZERO, leaf)
	for y in [0.35, h - 0.35]:
		add_box(Vector3(w * 0.95, 0.06, 0.09), Vector3(0, y, 0), mat("iron"), false, Vector3.ZERO, leaf)
	for face in [1.0, -1.0]:
		add_cylinder(0.05, 0.015, Vector3(w * 0.36, h * 0.47, face * 0.06), mat("brass"), false, Vector3(90, 0, 0), leaf)
	if sign_text != "":
		add_box(Vector3(minf(width - 0.3, 1.3), 0.3, 0.05), Vector3(0, door_height + 0.32, thickness * 0.5 + 0.03), mat("wood_dark"), false)
		add_label(sign_text, Vector3(0, door_height + 0.32, thickness * 0.5 + 0.06), 36)


func get_interaction_text() -> String:
	return prompt


func interact(_player: Player) -> void:
	SceneManager.change_scene(target_scene, target_spawn)
