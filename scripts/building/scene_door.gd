@tool
class_name SceneDoor
extends KitWall
## A doorway wall with a closed door and a sign; E takes the player to
## another scene (fade, keep inventory/stats, arrive at a SpawnPoint).
## Used for the player room door and the way back from the dungeon.

@export_group("Destination")
@export_file("*.tscn") var target_scene: String = ""
## spawn_id of the SpawnPoint to arrive at in the target scene.
@export var target_spawn: StringName = &"default"
@export var prompt: String = "Enter"
@export var sign_text: String = ""

## The door leaf (Door_1_Round, hinge at its origin, leaf toward +X).
const LEAF_SIZE := Vector3(1.12, 2.32, 0.12)
const LEAF_MODEL := "Door_1_Round"
## Lowest sign height: just above the doorway's arch.
const SIGN_MIN_Y := 3.2


func _build() -> void:
	style = Style.DOORWAY
	super._build()
	# Closed door leaf (its own body so it's targetable), centred in the
	# doorway.
	var leaf := StaticBody3D.new()
	leaf.collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	add_generated(leaf)
	add_model_xform(mv(LEAF_MODEL), Transform3D(Basis.IDENTITY, Vector3(-LEAF_SIZE.x * 0.5, 0, 0)), leaf)
	add_collision_box(LEAF_SIZE, Vector3(0, LEAF_SIZE.y * 0.5, 0), Vector3.ZERO, leaf)
	if sign_text != "":
		# No sign model in the packs: a dark board with a label, on the wall's face.
		var y := maxf(door_height + 0.32, SIGN_MIN_Y)
		add_box(Vector3(1.3, 0.3, 0.05), Vector3(0, y, BODY_DEPTH * 0.5 + 0.03), mat("wood_dark"), false)
		add_label(sign_text, Vector3(0, y, BODY_DEPTH * 0.5 + 0.06), 36)


func get_interaction_text() -> String:
	return prompt


func interact(_player: Player) -> void:
	SceneManager.change_scene(target_scene, target_spawn)
