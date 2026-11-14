@tool
class_name KitBanner
extends KitPiece
## Hanging cloth banner (Fantasy Props Banner_1_Cloth). Red is the pack's
## own colour (vertex colours over a white cloth texture); blue and green
## are the same material with the colour set instead. Origin = the
## middle of the rod (hang it on a wall at about 2.7 m).

enum ClothColor { RED, BLUE, GREEN }

@export var cloth_color: ClothColor = ClothColor.RED
@export var width: float = 0.9
## Not used: the length follows the width (kept so existing scenes load).
@export var length: float = 1.7


const MODEL := "Banner_1_Cloth"
const CLOTH_MATERIAL := "MI_Banner"
## Cloth colours for blue and green (red keeps the model's vertex colours).
const COLORS := [Color(1, 1, 1), Color(0.24, 0.38, 0.66), Color(0.24, 0.5, 0.3)]

static var _cloths: Dictionary = {}


func _build() -> void:
	# Banner_1_Cloth (0.81 x 2.25 x 0.06 m with its rod), scaled evenly from
	# the width; it hangs from the rod at the origin, its back against the wall.
	var path := fp(MODEL)
	var src := model_aabb(path)
	var s := (width + 0.2) / src.size.x
	var holder := add_model(path, s, Vector3(0, 0.1 - src.size.y * s, src.size.z * s * 0.5))
	if cloth_color != ClothColor.RED:
		var cloth := _cloth(path, cloth_color)
		for mesh_instance in holder.get_children():
			var mesh := (mesh_instance as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				if mesh.surface_get_material(i) and mesh.surface_get_material(i).resource_name == CLOTH_MATERIAL:
					(mesh_instance as MeshInstance3D).set_surface_override_material(i, cloth)


## The pack's cloth material in another colour (shared per colour).
static func _cloth(path: String, color: int) -> Material:
	if not _cloths.has(color):
		var base := KitPiece.model_material(path, CLOTH_MATERIAL) as BaseMaterial3D
		var copy := base.duplicate() as BaseMaterial3D
		copy.vertex_color_use_as_albedo = false
		copy.albedo_color = COLORS[color]
		_cloths[color] = copy
	return _cloths[color]
