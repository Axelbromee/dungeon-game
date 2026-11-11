class_name SpawnPoint
extends Marker3D
## Where the player appears when a scene is entered with this spawn_id
## (see SceneManager.change_scene). The player faces this node's -Z.
## A scene's "default" spawn is used when no id (or an unknown one) is given.

@export var spawn_id: StringName = &"default"


func _ready() -> void:
	add_to_group("spawn_points")
