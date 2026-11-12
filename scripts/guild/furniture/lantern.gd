@tool
class_name KitLantern
extends KitPiece
## KayKit lantern hanging on an iron chain. Origin = the attach point on the ceiling.
## The glass glows with emission; a real light is OFF by default (there's an
## 8-lights-per-object limit), so only enable it on a few lanterns.

@export var chain_length: float = 0.8
@export var light_enabled: bool = false
@export var light_energy: float = 1.6
@export var light_range: float = 7.0
@export var light_color: Color = Color(1.0, 0.68, 0.35)
@export var flicker: bool = true


func _build() -> void:
	var iron := mat("iron")
	add_box(Vector3(0.12, 0.03, 0.12), Vector3(0, -0.015, 0), iron, false)
	# Chain links (alternating orientation).
	var link := 0.07
	var links := maxi(int(chain_length / link), 1)
	for i in links:
		add_box(Vector3(0.02 if i % 2 == 0 else 0.035, link * 0.9, 0.035 if i % 2 == 0 else 0.02), Vector3(0, -(i + 0.5) * link, 0), iron, false)
	var top := -links * link
	# KayKit lantern hanging by its handle, with a warm glow inside.
	var body_h := 0.42
	add_model_sized(kk("lantern"), Vector3(0, top - body_h, 0), body_h)
	var glow_y := top - body_h * 0.62
	add_box(Vector3(0.1, 0.12, 0.1), Vector3(0, glow_y, 0), mat("glow_warm"), false)

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
