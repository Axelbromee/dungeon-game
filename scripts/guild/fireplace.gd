@tool
class_name KitFireplace
extends KitPiece
## Stone fireplace with a mantel, chimney, logs, flames and ONE real light
## (keep the scene under the 8-lights-per-object limit). Front is +Z; put
## the back against a wall.

@export var width: float = 2.2
@export var height: float = 2.4
@export var depth: float = 0.8
@export var opening_width: float = 1.2
@export var opening_height: float = 1.0
## Chimney top (set it to the ceiling height).
@export var chimney_height: float = 3.0
@export var has_light: bool = true
@export var light_energy: float = 3.0
@export var light_range: float = 9.0
@export var light_color: Color = Color(1.0, 0.55, 0.22)


func _build() -> void:
	var stone := mat("stone_pillar")
	var half_w := width * 0.5
	var side_w := (width - opening_width) * 0.5
	# Sides, lintel and back of the firebox.
	for sx in [-1.0, 1.0]:
		add_box(Vector3(side_w, height, depth), Vector3(sx * (half_w - side_w * 0.5), height * 0.5, 0), stone)
	add_box(Vector3(opening_width, height - opening_height, depth), Vector3(0, (height + opening_height) * 0.5, 0), stone)
	add_box(Vector3(opening_width, opening_height, 0.2), Vector3(0, opening_height * 0.5, -depth * 0.5 + 0.1), mat("stone_wall"))
	add_box(Vector3(opening_width, 0.02, depth - 0.2), Vector3(0, 0.01, 0.1), mat("void"), false)  # Soot.
	# Mantel and hearth.
	add_box(Vector3(width + 0.2, 0.12, depth * 0.55), Vector3(0, height * 0.62, depth * 0.3), mat("wood_dark"), false)
	add_box(Vector3(width + 0.3, 0.08, 0.6), Vector3(0, 0.04, depth * 0.5 + 0.28), mat("stone"))
	# Chimney.
	if chimney_height > height:
		add_box(Vector3(width * 0.6, chimney_height - height, depth * 0.7), Vector3(0, (height + chimney_height) * 0.5, -depth * 0.15), mat("stone_wall"))

	# Logs and glowing embers.
	var log_mat := mat("wood_dark")
	add_cylinder(0.07, opening_width * 0.7, Vector3(0, 0.1, 0.02), log_mat, false, Vector3(0, 0, 90))
	add_cylinder(0.06, opening_width * 0.6, Vector3(0.05, 0.2, -0.05), log_mat, false, Vector3(0, 25, 90))
	add_box(Vector3(opening_width * 0.6, 0.04, 0.3), Vector3(0, 0.04, 0), mat("glow_warm"), false)

	# Flames: three emitters across the logs.
	for i in 3:
		var flame := GPUParticles3D.new()
		flame.amount = 22
		flame.lifetime = 0.8
		flame.process_material = load("res://materials/fire_flame_process.tres")
		var quad := QuadMesh.new()
		quad.size = Vector2(0.35, 0.35)
		quad.material = load("res://materials/fire_particle.tres")
		flame.draw_pass_1 = quad
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3((i - 1) * opening_width * 0.22, 0.22, 0.0)
		add_generated(flame)

	if has_light:
		var light := OmniLight3D.new()
		light.light_color = light_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.omni_attenuation = 1.2
		light.position = Vector3(0, 0.7, depth * 0.5 + 0.4)
		light.set_script(load("res://scripts/flicker_light.gd"))
		add_generated(light)
