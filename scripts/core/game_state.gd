extends Node
## Autoload "GameState": data that must survive scene changes.
## - player_data: the Player's inventory, HP, mana, stamina, level, XP, stats
##   and hotbar selection (written by SceneManager before a scene change,
##   read by the Player when the next scene starts).
## - storages: contents of every storage chest, by storage_id.
## - pending_spawn: SpawnPoint id the Player should appear at next.

var player_data: Dictionary = {}
var storages: Dictionary = {}
var pending_spawn: StringName = &""


func has_player_data() -> bool:
	return not player_data.is_empty()


func get_storage(storage_id: StringName) -> Array:
	return storages.get(storage_id, [])


func set_storage(storage_id: StringName, data: Array) -> void:
	storages[storage_id] = data
