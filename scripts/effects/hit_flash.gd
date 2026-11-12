class_name HitFlash
## Briefly overlays a hot orange tint on every mesh under `root`.

static var _material: StandardMaterial3D


static func flash(root: Node, duration: float = 0.12) -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.albedo_color = Color(1.0, 0.45, 0.1, 0.7)

	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		(mesh as MeshInstance3D).material_overlay = _material

	root.get_tree().create_timer(duration).timeout.connect(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh):
				(mesh as MeshInstance3D).material_overlay = null
	)
