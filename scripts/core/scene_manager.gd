extends CanvasLayer
## Autoload "SceneManager": fade to black, save the player, load another
## scene, then fade back in. The Player in the new scene restores itself from
## GameState and moves to the SpawnPoint whose spawn_id was requested.
##   SceneManager.change_scene("res://scenes/world/player_room.tscn", &"from_guild")

signal scene_change_started(path: String)
signal scene_change_finished(path: String)

## Seconds for each half of the fade.
@export var fade_time: float = 0.35
@export var fade_color: Color = Color(0.0, 0.0, 0.0)

var is_changing: bool = false

var _fade: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(fade_color, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func change_scene(path: String, spawn_id: StringName = &"") -> void:
	if is_changing or path == "":
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: scene not found: %s" % path)
		return
	is_changing = true
	scene_change_started.emit(path)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP  # Swallow clicks mid-fade.

	await _fade_to(1.0)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		GameState.player_data = player.save_state()
	GameState.pending_spawn = spawn_id
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneManager: failed to load %s (error %d)" % [path, error])
	# Let the new scene enter the tree and place the player before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_changing = false
	scene_change_finished.emit(path)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, fade_time)
	await tween.finished
