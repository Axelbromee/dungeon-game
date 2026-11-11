class_name ItemVisuals
## Builds a display-only copy of an item scene: its meshes / particles,
## without the physics body, collision shapes or pickup script. Used for the
## first-person hand and for generated inventory icons.


## `as_is` keeps a non-physics root intact (custom held models).
static func build(scene: PackedScene, as_is: bool = false) -> Node3D:
	if scene == null:
		return null
	var instance := scene.instantiate()
	var visual: Node3D
	if as_is and instance is Node3D and not (instance is PhysicsBody3D):
		visual = instance as Node3D
	else:
		visual = Node3D.new()
		visual.name = "Visual"
		for child in instance.get_children():
			if child is CollisionShape3D or child is CollisionPolygon3D:
				continue
			# Clear ownership first, or Godot warns that the old scene root
			# still owns nodes that now live under a different parent.
			for owned in [child] + child.find_children("*", "", true, false):
				if owned.owner == instance:
					owned.owner = null
			instance.remove_child(child)
			visual.add_child(child)
		instance.free()
	for geometry in visual.find_children("*", "GeometryInstance3D", true, false):
		(geometry as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


## Combined bounds of every visual instance under `root`, in root space.
static func local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if visual is GPUParticles3D:
			continue  # Particle AABBs are huge placeholders.
		var xform := Transform3D.IDENTITY
		var walk: Node = visual
		while walk != null and walk != root:
			if walk is Node3D:
				xform = (walk as Node3D).transform * xform
			walk = walk.get_parent()
		var box := xform * visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result if not first else AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
