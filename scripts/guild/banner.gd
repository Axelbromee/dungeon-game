@tool
class_name KitBanner
extends KitPiece
## Hanging cloth banner with a brass rod and a diamond emblem. Origin = the
## middle of the rod (hang it on a wall at about 2.7 m).

enum ClothColor { RED, BLUE, GREEN }

@export var cloth_color: ClothColor = ClothColor.RED
@export var width: float = 0.9
@export var length: float = 1.7


func _build() -> void:
	var cloth: Material = mat(["cloth_red", "cloth_blue", "cloth_green"][cloth_color])
	var brass := mat("brass")
	add_cylinder(0.02, width + 0.2, Vector3.ZERO, brass, false, Vector3(0, 0, 90))
	for sx in [-1.0, 1.0]:
		add_sphere(0.035, Vector3(sx * (width * 0.5 + 0.1), 0, 0), brass)
	add_box(Vector3(width, length, 0.02), Vector3(0, -length * 0.5 - 0.02, 0), cloth, false)
	# Pointed bottom: two rotated halves.
	var tip := width * 0.36
	for sx in [-1.0, 1.0]:
		add_box(Vector3(width * 0.72, width * 0.72, 0.02), Vector3(sx * width * 0.25, -length - 0.02, 0), cloth, false, Vector3(0, 0, 45)).scale = Vector3(0.7, 0.7, 1.0)
	# Emblem: brass diamond with a dark centre, and a trim line.
	add_box(Vector3(width * 0.4, width * 0.4, 0.025), Vector3(0, -length * 0.4, 0.004), brass, false, Vector3(0, 0, 45))
	add_box(Vector3(width * 0.22, width * 0.22, 0.03), Vector3(0, -length * 0.4, 0.006), mat("wood_dark"), false, Vector3(0, 0, 45))
	add_box(Vector3(width, 0.03, 0.025), Vector3(0, -0.12, 0.003), brass, false)
	add_box(Vector3(width, 0.03, 0.025), Vector3(0, -length + tip * 0.2, 0.003), brass, false)
