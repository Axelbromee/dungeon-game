class_name FlickerLight
extends OmniLight3D
## Warm fire-light flicker. Layered sines with a random phase so neighbouring
## torches don't pulse in sync.

@export var flicker_amount: float = 0.25
@export var flicker_speed: float = 1.0

var _base_energy: float
var _base_range: float
var _t: float


func _ready() -> void:
	_base_energy = light_energy
	_base_range = omni_range
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	var n := sin(_t * 7.3) * 0.5 + sin(_t * 13.1 + 1.7) * 0.3 + sin(_t * 23.7 + 0.4) * 0.2
	light_energy = _base_energy * (1.0 + flicker_amount * n)
	omni_range = _base_range * (1.0 + flicker_amount * 0.15 * n)
