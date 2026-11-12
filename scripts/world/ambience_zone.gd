class_name AmbienceZone
extends Area3D
## While the player is inside this area, the scene's ambient light fades to
## this zone's colour and energy (e.g. a cool, dark cellar) and fades back
## when they leave. Works on a copy of the Environment, so the scene's saved
## one never changes (and stays right when the scene is loaded again).

@export var world_environment: WorldEnvironment
@export var ambient_color: Color = Color(0.4, 0.46, 0.6)
@export var ambient_energy: float = 0.28
@export var fade_time: float = 1.2

var _env: Environment
var _outside_color: Color
var _outside_energy: float
var _tween: Tween


func _ready() -> void:
	if world_environment == null or world_environment.environment == null:
		push_warning("AmbienceZone: no WorldEnvironment set")
		return
	_env = world_environment.environment.duplicate() as Environment
	world_environment.environment = _env
	_outside_color = _env.ambient_light_color
	_outside_energy = _env.ambient_light_energy
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_fade(ambient_color, ambient_energy)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_fade(_outside_color, _outside_energy)


func _fade(color: Color, energy: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_env, "ambient_light_color", color, fade_time)
	_tween.tween_property(_env, "ambient_light_energy", energy, fade_time)
