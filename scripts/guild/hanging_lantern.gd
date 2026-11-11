@tool
class_name KitLantern
extends KitPiece
## Iron lantern hanging on a chain. Origin = the attach point on the ceiling.
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
	# Cage: cap, posts, glass, base.
	add_cylinder(0.13, 0.12, Vector3(0, top - 0.06, 0), iron, false, Vector3.ZERO, null, 4, 0.02)
	add_cylinder(0.035, 0.04, Vector3(0, top - 0.01, 0), iron, false)
	var body_top := top - 0.12
	var body_h := 0.28
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_box(Vector3(0.02, body_h, 0.02), Vector3(sx * 0.085, body_top - body_h * 0.5, sz * 0.085), iron, false)
	add_box(Vector3(0.15, body_h - 0.02, 0.15), Vector3(0, body_top - body_h * 0.5, 0), mat("glow_warm"), false)
	add_box(Vector3(0.2, 0.03, 0.2), Vector3(0, body_top - body_h - 0.015, 0), iron, false)
	add_cylinder(0.03, 0.05, Vector3(0, body_top - body_h - 0.05, 0), iron, false)

	if light_enabled:
		var light := OmniLight3D.new()
		light.light_color = light_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.omni_attenuation = 1.3
		light.position = Vector3(0, body_top - body_h * 0.5, 0)
		if flicker:
			light.set_script(load("res://scripts/flicker_light.gd"))
			light.set("flicker_amount", 0.1)
		add_generated(light)
