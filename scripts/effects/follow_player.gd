extends Node3D
## Keeps this node on the player, e.g. ambient particles (fireflies, magic
## motes) that should always be around wherever the player walks. Give the
## particles world coordinates (local_coords off) so they stay put while the
## emitter moves.

@export var offset: Vector3 = Vector3.ZERO

var _player: Node3D


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	global_position = _player.global_position + offset
