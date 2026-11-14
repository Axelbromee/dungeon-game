@tool
class_name KitPiece
extends StaticBody3D
## Base for the procedural building kit and guild furniture. A piece builds
## its meshes and collision from its exported settings in _build(), at
## runtime and live in the editor (when a setting changes it rebuilds).
## Generated nodes aren't saved into scenes; only the settings are.
##
## Conventions: origin at floor level, centred on the piece; pieces snap to a
## 2 m grid (GRID); "front" is +Z.

const GRID := 2.0
## Physics layers: 1 = world, 2 = player_only (ramps), 3 = interactable.
const LAYER_WORLD := 1
const LAYER_PLAYER_ONLY := 2
const LAYER_INTERACTABLE := 4

## Folders of the Quaternius packs (meshes for the kit pieces and props).
const MEDIEVAL := "res://new assets/Medieval Village MegaKit[Standard]/Medieval Village MegaKit[Standard]/glTF/"
const PROPS := "res://new assets/Fantasy Props MegaKit[Standard]/Exports/glTF/"
const NATURE := "res://new assets/Stylized Nature MegaKit[Standard]/glTF/"

static var _materials: Dictionary = {}


## Path of a Medieval Village model by name, e.g. mv("Wall_UnevenBrick_Straight").
static func mv(model_name: String) -> String:
	return MEDIEVAL + model_name + ".gltf"


## Path of a Fantasy Props model by name, e.g. fp("Barrel").
static func fp(model_name: String) -> String:
	return PROPS + model_name + ".gltf"


## Path of a Stylized Nature model by name, e.g. nat("CommonTree_1").
static func nat(model_name: String) -> String:
	return NATURE + model_name + ".gltf"


## A model's own material by name (e.g. "MI_UnevenBrick"), shared.
static func model_material(path: String, material_name: String) -> Material:
	for part in model_parts(path):
		var mesh := part["mesh"] as Mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i)
			if material and material.resource_name == material_name:
				return material
	return null


## A copy of a model's own material mapped in world space (triplanar), for
## plain boxes that fill gaps between pack pieces. `tile` = metres per
## texture repeat.
static func pack_box_material(path: String, material_name: String, tile: float = 2.0) -> Material:
	var key := "%s|%s|%s" % [path, material_name, tile]
	if _materials.has(key):
		return _materials[key]
	var base := model_material(path, material_name) as BaseMaterial3D
	var material: BaseMaterial3D
	if base:
		material = base.duplicate() as BaseMaterial3D
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE / tile
		material.uv1_offset = Vector3.ZERO
	else:
		material = _flat(Color(0.6, 0.55, 0.5), 0.9)
	_materials[key] = material
	return material

var _signature: String = ""
var _generated: Array[Node] = []


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		set_process(false)


func _process(_delta: float) -> void:
	# Editor only: rebuild when any exported setting changes.
	if Engine.is_editor_hint() and _make_signature() != _signature:
		_rebuild()


## Override: create the piece with add_box() & co.
func _build() -> void:
	pass


func _rebuild() -> void:
	_signature = _make_signature()
	for node in _generated:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()
	_build()


func _make_signature() -> String:
	var parts := PackedStringArray()
	for property in get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			parts.append(str(get(property["name"])))
	return "|".join(parts)


# --- Builders ---------------------------------------------------------------

## A box mesh. If `collide`, a matching box collider is added to `body`
## (default: this piece). Collision only works when the mesh's parent is that
## body, so pass the same node for both when building moving parts.
func add_box(size: Vector3, pos: Vector3, material: Material, collide: bool = true,
		rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh_instance(mesh, pos, material, rot_deg, parent)
	if collide:
		add_collision_box(size, pos, rot_deg, parent)
	return instance


func add_cylinder(radius: float, height: float, pos: Vector3, material: Material,
		collide: bool = false, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null,
		sides: int = 12, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var instance := _mesh_instance(mesh, pos, material, rot_deg, parent)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_collision(shape, pos, rot_deg, parent)
	return instance


func add_sphere(radius: float, pos: Vector3, material: Material, scale_vec: Vector3 = Vector3.ONE,
		parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := _mesh_instance(mesh, pos, material, Vector3.ZERO, parent)
	instance.scale = scale_vec
	return instance


func add_collision_box(size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO,
		parent: Node3D = null) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return _collision(shape, pos, rot_deg, parent)


func add_label(text: String, pos: Vector3, font_size: int = 48, color: Color = Color(1, 0.92, 0.75),
		rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0.05, 0.03, 0.02, 0.9)
	label.position = pos
	label.rotation_degrees = rot_deg
	label.double_sided = false
	add_generated(label, parent)
	return label


## A model (e.g. a pack .gltf) at uniform scale `s`, turned `rot_y_deg`
## around Y, with the bottom centre of its bounds at `bottom` (in the
## parent's space). Models are never stretched: pick a scale, use several
## pieces, or a bigger model. `only` / `skip` pick mesh parts by node name;
## the bounds are those of the picked parts. Returns the holder node.
func add_model(path: String, s: float, bottom: Vector3, rot_y_deg: float = 0.0, parent: Node3D = null,
		only: PackedStringArray = PackedStringArray(), skip: PackedStringArray = PackedStringArray()) -> Node3D:
	return add_model_xform(path, uniform_xform(path, s, bottom, rot_y_deg, only, skip), parent, only, skip)


## The transform add_model() uses: uniform scale, bottom centre at `bottom`.
static func uniform_xform(path: String, s: float, bottom: Vector3, rot_y_deg: float = 0.0,
		only: PackedStringArray = PackedStringArray(), skip: PackedStringArray = PackedStringArray()) -> Transform3D:
	var src := model_aabb(path, only, skip)
	var model_basis := Basis(Vector3.UP, deg_to_rad(rot_y_deg)).scaled_local(Vector3.ONE * s)
	var placed := Transform3D(model_basis, Vector3.ZERO) * src
	var centre := placed.get_center()
	return Transform3D(model_basis, bottom - Vector3(centre.x, placed.position.y, centre.z))


## A model with uniform scale: `height` tall, its bottom centre at `bottom`.
func add_model_sized(path: String, bottom: Vector3, height: float, rot_y_deg: float = 0.0,
		parent: Node3D = null) -> Node3D:
	var src := model_aabb(path)
	var s := height / maxf(src.size.y, 0.001)
	var model_basis := Basis(Vector3.UP, deg_to_rad(rot_y_deg)).scaled_local(Vector3.ONE * s)
	var centre := src.get_center()
	var offset := model_basis * Vector3(centre.x, src.position.y, centre.z)
	return add_model_xform(path, Transform3D(model_basis, bottom - offset), parent)


## A model turned by `rot_deg` (Euler, degrees) with uniform scale so its
## longest side is `longest`, its bottom centre at `bottom`.
func add_model_posed(path: String, bottom: Vector3, longest: float, rot_deg: Vector3,
		parent: Node3D = null) -> Node3D:
	var src := model_aabb(path)
	var rot := Basis.from_euler(rot_deg * (PI / 180.0))
	var turned := Transform3D(rot, Vector3.ZERO) * src
	var s := longest / maxf(turned.size[turned.get_longest_axis_index()], 0.001)
	var model_basis := rot.scaled(Vector3.ONE * s)
	var placed := Transform3D(model_basis, Vector3.ZERO) * src
	var centre := placed.get_center()
	return add_model_xform(path, Transform3D(model_basis, bottom - Vector3(centre.x, placed.position.y, centre.z)), parent)


## A model with an explicit transform (model space -> parent space).
func add_model_xform(path: String, xform: Transform3D, parent: Node3D = null,
		only: PackedStringArray = PackedStringArray(), skip: PackedStringArray = PackedStringArray()) -> Node3D:
	var holder := Node3D.new()
	holder.transform = xform
	for part in _filtered_parts(path, only, skip):
		var instance := MeshInstance3D.new()
		instance.mesh = part["mesh"]
		instance.transform = part["xform"]
		holder.add_child(instance)
	add_generated(holder, parent)
	return holder


## Bounds of a model's meshes (optionally only some parts), in model space.
static func model_aabb(path: String, only: PackedStringArray = PackedStringArray(),
		skip: PackedStringArray = PackedStringArray()) -> AABB:
	var result := AABB()
	var first := true
	for part in _filtered_parts(path, only, skip):
		var box: AABB = part["xform"] * (part["mesh"] as Mesh).get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Transform of one named part inside its model (e.g. a lid's hinge).
static func model_part_xform(path: String, part_name: String) -> Transform3D:
	for part in model_parts(path):
		if part["name"] == part_name:
			return part["xform"]
	return Transform3D.IDENTITY


static var _models: Dictionary = {}

## Every mesh in a model scene: [{name, mesh, xform}], xform relative to
## the model root. Loaded once and shared.
static func model_parts(path: String) -> Array:
	if _models.has(path):
		return _models[path]
	var parts: Array = []
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("KitPiece: can't load model %s" % path)
	else:
		var root := scene.instantiate() as Node3D
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			var xform := Transform3D.IDENTITY
			var walk: Node = mesh_node
			while walk != null and walk != root:
				xform = (walk as Node3D).transform * xform
				walk = walk.get_parent()
			parts.append({"name": String(mesh_node.name), "mesh": nature_mesh(mesh_node.mesh), "xform": xform})
		root.free()
	_models[path] = parts
	return parts


## Stylized Nature leaf materials: the free pack's leaf textures are only
## cut-out masks, so these colour them (materials/nature, foliage shader).
const LEAF_MATERIALS := {
	"Leaves_NormalTree": "res://materials/nature/leaves_normal_tree.tres",
	"Leaves_TwistedTree": "res://materials/nature/leaves_twisted_tree.tres",
	"Leaves_Pine": "res://materials/nature/leaves_pine.tres",
}

static var _nature_meshes: Dictionary = {}


## The mesh with any Stylized Nature leaf material swapped for its coloured
## version (shared copy; other meshes are returned unchanged).
static func nature_mesh(mesh: Mesh) -> Mesh:
	if mesh == null:
		return mesh
	if _nature_meshes.has(mesh):
		return _nature_meshes[mesh]
	var result := mesh
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i)
		if material and LEAF_MATERIALS.has(material.resource_name):
			if result == mesh:
				result = mesh.duplicate()
			result.surface_set_material(i, load(LEAF_MATERIALS[material.resource_name]))
	_nature_meshes[mesh] = result
	return result


static func _filtered_parts(path: String, only: PackedStringArray, skip: PackedStringArray) -> Array:
	var result: Array = []
	for part in model_parts(path):
		if not only.is_empty() and not only.has(part["name"]):
			continue
		if skip.has(part["name"]):
			continue
		result.append(part)
	return result


## Adds any node as a generated (rebuilt, never saved) child.
func add_generated(node: Node, parent: Node = null) -> Node:
	var target: Node = parent if parent else self
	target.add_child(node)
	if target == self:
		_generated.append(node)
	return node


func _mesh_instance(mesh: Mesh, pos: Vector3, material: Material, rot_deg: Vector3,
		parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_deg
	add_generated(instance, parent)
	return instance


func _collision(shape: Shape3D, pos: Vector3, rot_deg: Vector3, parent: Node3D) -> CollisionShape3D:
	var body: Node3D = parent if parent is CollisionObject3D else self
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = pos
	collider.rotation_degrees = rot_deg
	add_generated(collider, body)
	return collider


## Small deterministic per-piece randomness (same look every rebuild).
func make_rng(salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(global_position if is_inside_tree() else position)) + salt
	return rng


# --- Materials --------------------------------------------------------------

## Shared materials by name: wood, wood_dark, wood_light, plank_a/b/c,
## stone, stone_wall, stone_pillar, plaster, iron, brass, cloth_red,
## cloth_blue, cloth_green, parchment, cork, glow_warm, glass, straw,
## blanket, linen, void.
static func mat(material_name: String) -> Material:
	if _materials.has(material_name):
		return _materials[material_name]
	var material: Material
	match material_name:
		"wood":
			material = _tinted("res://materials/surfaces/wood.tres", Color(1, 1, 1))
		"wood_dark":
			material = _tinted("res://materials/surfaces/wood.tres", Color(0.5, 0.42, 0.36))
		"wood_light":
			material = _tinted("res://materials/surfaces/wood.tres", Color(1.25, 1.15, 1.0))
		"plank_a":
			material = _tinted("res://materials/surfaces/wood.tres", Color(0.95, 0.88, 0.8))
		"plank_b":
			material = _tinted("res://materials/surfaces/wood.tres", Color(0.82, 0.74, 0.66))
		"plank_c":
			material = _tinted("res://materials/surfaces/wood.tres", Color(1.05, 0.95, 0.85))
		"stone":
			material = load("res://materials/surfaces/stone_floor.tres")
		"stone_wall":
			material = load("res://materials/surfaces/stone_wall.tres")
		"stone_pillar":
			material = load("res://materials/surfaces/stone_pillar.tres")
		"iron":
			material = load("res://materials/surfaces/iron.tres")
		"plaster":
			material = _flat(Color(0.9, 0.84, 0.74), 0.95)
		"brass":
			var brass := _flat(Color(0.95, 0.72, 0.32), 0.45)
			brass.metallic = 0.4
			material = brass
		"cloth_red":
			material = _flat(Color(0.82, 0.22, 0.25), 1.0)
		"cloth_blue":
			material = _flat(Color(0.27, 0.46, 0.76), 1.0)
		"cloth_green":
			material = _flat(Color(0.27, 0.6, 0.36), 1.0)
		"parchment":
			material = _flat(Color(0.96, 0.89, 0.7), 1.0)
		"cork":
			material = _flat(Color(0.8, 0.58, 0.4), 1.0)
		"straw":
			material = _flat(Color(0.96, 0.8, 0.44), 1.0)
		"blanket":
			material = _flat(Color(0.76, 0.22, 0.26), 1.0)
		"linen":
			material = _flat(Color(0.95, 0.92, 0.86), 1.0)
		"glow_warm":
			var glow := _flat(Color(1.0, 0.72, 0.4), 0.5)
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.62, 0.25)
			glow.emission_energy_multiplier = 3.0
			material = glow
		"glass":
			var glass := _flat(Color(0.6, 0.7, 0.75, 0.3), 0.05)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.metallic_specular = 1.0
			material = glass
		"void":
			var void_mat := StandardMaterial3D.new()
			void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			void_mat.albedo_color = Color(0.0, 0.0, 0.0)
			material = void_mat
		_:
			material = _flat(Color(1, 0, 1), 1.0)  # Magenta = unknown name.
	_materials[material_name] = material
	return material


static func _tinted(path: String, tint: Color) -> Material:
	var base := load(path) as StandardMaterial3D
	if base == null:
		return _flat(tint, 0.8)
	var copy := base.duplicate() as StandardMaterial3D
	copy.albedo_color = base.albedo_color * tint
	return copy


static func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
