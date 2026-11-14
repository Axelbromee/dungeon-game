@tool
class_name KitLantern
extends KitPiece
## Fantasy Props chandelier (a candle ring on its own iron chain), hanging
## from the ceiling. Origin = the attach point on the ceiling. The candle
## flames glow with emission; a real light is OFF by default (there's an
## 8-lights-per-object limit), so only enable it on a few lanterns.

@export var chain_length: float = 0.8
@export var light_enabled: bool = false
@export var light_energy: float = 1.6
@export var light_range: float = 7.0
@export var light_color: Color = Color(1.0, 0.68, 0.35)
@export var flicker: bool = true


## Chandelier: 1.3 x 1.46 m, hanging from its top (model y 0.04); eight
## candles on a ring of radius 0.56 with their tips at model y -0.92.
const MODEL := "Chandelier"
const MODEL_TOP := 0.04
const MODEL_HEIGHT := 1.46
const CANDLES := 8
const CANDLE_RADIUS := 0.56
const CANDLE_TIP := -0.92


func _build() -> void:
	# Scaled evenly so it hangs as low as the old chain + lantern did.
	var s := (chain_length + 0.42) / MODEL_HEIGHT
	add_model_xform(fp(MODEL), Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(0, -MODEL_TOP * s, 0)))
	var glow_y := (CANDLE_TIP - MODEL_TOP) * s
	var glow := mat("glow_warm")
	for i in CANDLES:
		var angle := TAU * i / CANDLES
		var at := Vector3(cos(angle) * CANDLE_RADIUS * s, glow_y + 0.03 * s, sin(angle) * CANDLE_RADIUS * s)
		add_box(Vector3(0.03, 0.06, 0.03) * s, at, glow, false)

	if light_enabled:
		var light := OmniLight3D.new()
		light.light_color = light_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.omni_attenuation = 1.3
		light.position = Vector3(0, glow_y, 0)
		if flicker:
			light.set_script(load("res://scripts/effects/flicker_light.gd"))
			light.set("flicker_amount", 0.1)
		add_generated(light)
