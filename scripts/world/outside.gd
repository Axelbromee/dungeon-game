@tool
class_name GuildOutside
extends Node3D
## The world around the guild hall, seen through its windows: a grassy
## ground with a dirt path from the front doors, a few trees near the hall
## that thicken into a forest reaching the horizon, plus bushes, rocks and
## grass tufts (all KayKit nature models).
##
## Built from code like the building kit: generated at runtime and live in
## the editor (rebuilt when a setting changes); generated nodes aren't saved,
## only the settings. Same seed = same layout. Saved children (the Sun) are
## left alone.
##
## Nothing out here collides (the player can't go outside yet). Trees near
## the hall are separate meshes with shadows; the many distant ones are
## MultiMeshes without shadows, split into pie slices around the hall so the
## camera only draws the slices it looks at.

const NATURE := "res://KayKit/Assets4/gltf/%s_Color1.gltf"
const GROUND_MATERIAL := "res://materials/world/grass_ground.tres"
const PATH_MATERIAL := "res://materials/world/dirt_path.tres"

## Small trees are used close to the walls, where big ones would poke into
## the building.
const TREES_SMALL := ["Tree_1_A", "Tree_1_B", "Tree_2_A", "Tree_2_B", "Tree_3_A", "Tree_3_B", "Tree_4_A", "Tree_4_B"]
const TREES_BIG := ["Tree_1_C", "Tree_2_C", "Tree_2_D", "Tree_2_E", "Tree_3_C", "Tree_4_C"]
const TREES_BARE := ["Tree_Bare_1_B", "Tree_Bare_1_C", "Tree_Bare_2_B", "Tree_Bare_2_C"]
## Distant forest: the lighter models (under ~1000 triangles each).
const TREES_FAR := ["Tree_1_A", "Tree_1_B", "Tree_2_A", "Tree_2_B", "Tree_2_C", "Tree_3_A", "Tree_3_B", "Tree_4_A", "Tree_4_B", "Tree_4_C"]
const BUSHES_SMALL := ["Bush_1_B", "Bush_1_C", "Bush_2_A", "Bush_2_B", "Bush_3_A", "Bush_4_A", "Bush_4_B"]
const BUSHES := ["Bush_1_C", "Bush_1_D", "Bush_1_E", "Bush_1_F", "Bush_2_B", "Bush_2_C", "Bush_2_D", "Bush_2_E",
		"Bush_3_B", "Bush_3_C", "Bush_4_C", "Bush_4_D", "Bush_4_E"]
const BUSHES_FAR := ["Bush_1_D", "Bush_2_C", "Bush_3_B", "Bush_4_C"]
const ROCKS_SMALL := ["Rock_1_A", "Rock_1_B", "Rock_1_C", "Rock_2_B", "Rock_3_A", "Rock_3_B", "Rock_3_C", "Rock_3_D", "Rock_3_E", "Rock_3_F"]
const ROCKS_MEDIUM := ["Rock_1_D", "Rock_1_E", "Rock_1_F", "Rock_1_G", "Rock_1_H", "Rock_2_C", "Rock_2_D",
		"Rock_3_G", "Rock_3_H", "Rock_3_I", "Rock_3_J", "Rock_3_K", "Rock_3_L"]
const ROCKS_LARGE := ["Rock_1_J", "Rock_1_K", "Rock_1_N", "Rock_1_O", "Rock_2_E", "Rock_2_F", "Rock_2_G", "Rock_2_H",
		"Rock_3_M", "Rock_3_N", "Rock_3_O", "Rock_3_Q", "Rock_3_R"]
## Few variants so the scattered forest boulders stay a handful of MultiMeshes.
const ROCKS_FAR := ["Rock_1_G", "Rock_1_J", "Rock_2_D", "Rock_2_E", "Rock_3_K", "Rock_3_Q"]
## Trees claim this fraction of their crown width (trunk and lower crown):
## crowns may touch, but trunks, rocks and bushes never overlap.
const TREE_FOOTPRINT := 0.5
const TAKEN_CELL := 4.0
const TAKEN_MAX_RADIUS := 6.0
const GRASS := ["Grass_1_B", "Grass_1_C", "Grass_2_B", "Grass_2_C", "Grass_1_D", "Grass_2_D"]

## Same seed, same layout. Change it to reshuffle everything.
@export var layout_seed: int = 7

@export_group("Layout")
## Half size (x, z) of the hall's outer wall faces, centred on this node.
@export var walls_half_size := Vector2(10.5, 15.5)
## Z of the front wall's outer face (the path starts here, at x = 0).
@export var front_door_z: float = 15.5
## No trees closer than this to the walls.
@export var clearing: float = 7.0
## Trees, bushes and rocks closer than this to the walls are detailed
## (own meshes, cast shadows); further ones are MultiMesh forest.
@export var detail_distance: float = 40.0
## The forest reaches this far from the hall (the fog hides the edge).
@export var forest_radius: float = 300.0
## Ground plane width (square).
@export var ground_size: float = 1400.0

@export_group("Density")
## 0..1, how thick the forest gets.
@export_range(0.0, 1.0) var forest_density: float = 0.85
## Grid cell for tree candidates; smaller = more trees.
@export var tree_spacing: float = 3.5
## Grass tufts around the hall.
@export var grass_tufts: int = 1200
## Pie slices the forest is split into (for culling).
@export_range(4, 32) var forest_sectors: int = 12

@export_group("Path")
@export var path_width: float = 2.6
## Wider dirt patch right in front of the doors.
@export var path_door_width: float = 6.4
@export var path_length: float = 280.0

var _signature: String = ""
var _generated: Array[Node] = []
var _containers: Dictionary = {}
var _batches: Dictionary = {}
var _noise: FastNoiseLite
## Footprints placed so far (cell -> [Vector3(x, z, radius)]), so nothing
## clips into anything else.
var _taken: Dictionary = {}


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		set_process(false)


func _process(_delta: float) -> void:
	# Editor only: rebuild when any exported setting changes.
	if Engine.is_editor_hint() and _make_signature() != _signature:
		_rebuild()


func _rebuild() -> void:
	_signature = _make_signature()
	for node in _generated:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_generated.clear()
	_containers.clear()
	_batches.clear()
	_taken.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	_noise = FastNoiseLite.new()
	_noise.seed = layout_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.012

	_build_ground()
	_build_path()
	_scatter_trees(rng)
	_scatter_near_props(rng)
	_scatter_grass(rng)
	_flush_batches()


func _make_signature() -> String:
	var parts := PackedStringArray()
	for property in get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			parts.append(str(get(property["name"])))
	return "|".join(parts)


# --- Ground & path ------------------------------------------------------------

## Grass plane around the hall with a hole for the building (the hall's
## floor has an opening for the dungeon pit, so the ground mustn't run under
## it). Four strips; the material is world-triplanar so they line up.
func _build_ground() -> void:
	var ground := _container("Ground")
	var material := load(GROUND_MATERIAL) as Material
	var e := ground_size * 0.5
	# Inner edge hidden under the 1 m thick walls.
	var hx := walls_half_size.x - 0.5
	var hz := walls_half_size.y - 0.5
	var strips := {
		"North": Rect2(-e, -e, 2.0 * e, e - hz),
		"South": Rect2(-e, hz, 2.0 * e, e - hz),
		"West": Rect2(-e, -hz, e - hx, 2.0 * hz),
		"East": Rect2(hx, -hz, e - hx, 2.0 * hz),
	}
	for strip_name: String in strips:
		var rect: Rect2 = strips[strip_name]
		var plane := PlaneMesh.new()
		plane.size = rect.size
		# ~20 m cells so fog and light vary across the huge plane.
		plane.subdivide_width = ceili(rect.size.x / 20.0)
		plane.subdivide_depth = ceili(rect.size.y / 20.0)
		var instance := MeshInstance3D.new()
		instance.name = strip_name
		instance.mesh = plane
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var c := rect.get_center()
		instance.position = Vector3(c.x, 0.0, c.y)
		ground.add_child(instance)


## Dirt ribbon from the front doors, winding off into the forest.
func _build_path() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.0
	var z0 := front_door_z - 0.5
	var rows := int(path_length / step)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in rows + 1:
		var z := z0 + i * step
		var x := _path_x(z)
		var slope := (_path_x(z + 0.5) - _path_x(z - 0.5))
		var side := Vector2(1.0, -slope).normalized()
		var hw := _path_half_width(z)
		# Ragged edges.
		var wl := hw * (1.0 + 0.14 * _noise.get_noise_2d(z * 4.0, 100.0))
		var wr := hw * (1.0 + 0.14 * _noise.get_noise_2d(z * 4.0, -100.0))
		var l := Vector3(x - side.x * wl, 0.04, z - side.y * wl)
		var r := Vector3(x + side.x * wr, 0.04, z + side.y * wr)
		if i > 0:
			for v in [prev_l, prev_r, r, prev_l, r, l]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		prev_l = l
		prev_r = r
	var instance := MeshInstance3D.new()
	instance.name = "Path"
	instance.mesh = st.commit()
	instance.material_override = load(PATH_MATERIAL) as Material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(instance)


## Path centre line: x as a function of z (it only heads away from the door).
func _path_x(z: float) -> float:
	var t := maxf(z - front_door_z, 0.0)
	var ramp := smoothstep(0.0, 25.0, t)
	return ramp * (9.0 * sin(t * 0.035) + 3.0 * sin(t * 0.11))


func _path_half_width(z: float) -> float:
	var t := z - front_door_z
	return lerpf(path_door_width * 0.5, path_width * 0.5, smoothstep(2.0, 12.0, t))


## Distance from the path's edge (negative on the path); INF away from it.
func _path_distance(p: Vector2) -> float:
	if p.y < front_door_z - 1.0 or p.y > front_door_z + path_length:
		return INF
	var slope := _path_x(p.y + 0.5) - _path_x(p.y - 0.5)
	return absf(p.x - _path_x(p.y)) / sqrt(1.0 + slope * slope) - _path_half_width(p.y)


## Distance from the hall's outer walls (negative inside).
func _wall_distance(p: Vector2) -> float:
	var q := Vector2(absf(p.x) - walls_half_size.x, absf(p.y) - walls_half_size.y)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


# --- Trees & forest ------------------------------------------------------------

## How likely a tree grows at this distance from the walls: a few lone trees
## near the hall, thickening into forest.
func _tree_chance(d: float) -> float:
	if d < clearing:
		return 0.0
	if d < detail_distance:
		return lerpf(0.02, 0.45, pow(smoothstep(clearing, detail_distance, d), 1.6))
	return lerpf(0.45, 0.9, smoothstep(detail_distance, detail_distance + 40.0, d))


## Clumps and glades so the forest isn't even everywhere (about 0.1..1.25).
func _clump(p: Vector2) -> float:
	return clampf(0.65 + _noise.get_noise_2d(p.x, p.y) * 1.1, 0.1, 1.25)


func _scatter_trees(rng: RandomNumberGenerator) -> void:
	var cell := maxf(tree_spacing, 1.0)
	var n := ceili(forest_radius / cell)
	for ix in range(-n, n):
		for iz in range(-n, n):
			var p := Vector2((ix + rng.randf()) * cell, (iz + rng.randf()) * cell)
			var roll := rng.randf()
			var r := p.length()
			if r > forest_radius:
				continue
			var d := _wall_distance(p)
			if d < clearing:
				continue
			var clump := _clump(p)
			var path_d := _path_distance(p)
			var yaw := rng.randf() * TAU
			if d < detail_distance:
				if roll < _tree_chance(d) * clump * forest_density and path_d > 2.5:
					_place_near_tree(rng, p, d, yaw)
				continue
			# Distant forest: bigger trees further out, fewer of them, so the
			# canopy stays closed with fewer instances.
			var growth := clampf((r - 60.0) / 240.0, 0.0, 1.0)
			var chance := _tree_chance(d) * clump * forest_density / pow(1.0 + growth, 2.0)
			if roll < chance and path_d > 3.0 + growth * 2.0:
				var s := rng.randf_range(1.3, 1.8) * (1.0 + growth)
				var model := _pick(rng, TREES_FAR)
				if _claim(p, _radius(model, s, TREE_FOOTPRINT)):
					_queue(_sector_name(p), model, _xform(p, yaw, s))
			# Undergrowth and boulders between the trees (fog hides them further out).
			if r < 160.0 and path_d > 1.0 and rng.randf() < 0.12 * clump:
				var q := p + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
				var bush := _pick(rng, BUSHES_FAR)
				var bush_scale := rng.randf_range(1.0, 1.5)
				if _claim(q, _radius(bush, bush_scale)):
					_queue(_sector_name(q), bush, _xform(q, rng.randf() * TAU, bush_scale))
			if r < 200.0 and path_d > 1.0 and rng.randf() < 0.02:
				var rock := _pick(rng, ROCKS_FAR)
				var rock_scale := rng.randf_range(0.8, 1.4)
				if _claim(p, _radius(rock, rock_scale)):
					_queue("Forest/Rocks", rock, _rock_xform(rng, p, rock_scale))


func _place_near_tree(rng: RandomNumberGenerator, p: Vector2, d: float, yaw: float) -> void:
	var model: String
	if rng.randf() < 0.07:
		model = _pick(rng, TREES_BARE)
	elif d < 14.0 or rng.randf() < 0.5:
		model = _pick(rng, TREES_SMALL)
	else:
		model = _pick(rng, TREES_BIG)
	var s := rng.randf_range(1.15, 1.6)
	# Keep the crown off the walls, and the tree out of the other trees.
	if _radius(model, s) < d - 0.5 and _claim(p, _radius(model, s, TREE_FOOTPRINT)):
		_place("Trees", model, _xform(p, yaw, s))


## Forest slice for a spot, by its angle around the hall.
func _sector_name(p: Vector2) -> String:
	var slice := int(fposmod(atan2(p.y, p.x), TAU) / TAU * forest_sectors) % forest_sectors
	return "Forest/Sector%02d" % slice


# --- Bushes, rocks & grass near the hall ---------------------------------------------------

func _scatter_near_props(rng: RandomNumberGenerator) -> void:
	var cell := 2.5
	var ext := walls_half_size + Vector2.ONE * detail_distance
	for ix in range(floori(-ext.x / cell), ceili(ext.x / cell)):
		for iz in range(floori(-ext.y / cell), ceili(ext.y / cell)):
			var p := Vector2((ix + rng.randf()) * cell, (iz + rng.randf()) * cell)
			var bush_roll := rng.randf()
			var rock_roll := rng.randf()
			var yaw := rng.randf() * TAU
			var d := _wall_distance(p)
			if d < 0.6 or d > detail_distance:
				continue
			var path_d := _path_distance(p)
			var clump := _clump(p + Vector2(311.0, 173.0))
			# Bushes: a hedge of small ones along the walls, a few in the
			# open, more towards the forest edge.
			var bush_chance: float
			if d < 2.8:
				bush_chance = 0.22
			elif d < 12.0:
				bush_chance = 0.03
			else:
				bush_chance = lerpf(0.04, 0.2, smoothstep(12.0, detail_distance, d))
			if bush_roll < bush_chance * clump:
				var bushes: Array = BUSHES_SMALL if d < 2.8 else BUSHES
				var bush := _pick(rng, bushes)
				var bush_scale := rng.randf_range(0.85, 1.3)
				var bush_radius := _radius(bush, bush_scale)
				# Clear of the walls, the path and everything else.
				if d > bush_radius + 0.15 and path_d > bush_radius and _claim(p, bush_radius):
					_place("Bushes", bush, _xform(p, yaw, bush_scale))
				continue
			# Rocks: small ones lining the path, the odd boulder further out.
			var rock_chance := 0.012 if d < 12.0 else 0.03
			var rocks: Array = ROCKS_SMALL
			if path_d > 0.1 and path_d < 1.2:
				rock_chance = 0.08
			elif d > 20.0 and rng.randf() < 0.25:
				rocks = ROCKS_LARGE if rng.randf() < 0.35 else ROCKS_MEDIUM
			if path_d > 0.1 and rock_roll < rock_chance:
				var rock := _pick(rng, rocks)
				var rock_scale := rng.randf_range(0.8, 1.25)
				var rock_radius := _radius(rock, rock_scale)
				if d > rock_radius + 0.2 and path_d > rock_radius * 0.5 and _claim(p, rock_radius):
					_place("Rocks", rock, _rock_xform(rng, p, rock_scale))


## Grass tufts in little clusters around the hall (MultiMesh, no shadows).
func _scatter_grass(rng: RandomNumberGenerator) -> void:
	var ext := walls_half_size + Vector2.ONE * (detail_distance + 10.0)
	var placed := 0
	var attempts := 0
	while placed < grass_tufts and attempts < grass_tufts * 10:
		attempts += 1
		var c := Vector2(rng.randf_range(-ext.x, ext.x), rng.randf_range(-ext.y, ext.y))
		if _wall_distance(c) < 0.3:
			continue
		if rng.randf() > 0.35 + _noise.get_noise_2d(c.x * 3.0 + 500.0, c.y * 3.0):
			continue
		for _k in rng.randi_range(1, 4):
			var q := c + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
			var s := rng.randf_range(0.9, 1.5)
			var yaw := rng.randf() * TAU
			var model := _pick(rng, GRASS)
			if _wall_distance(q) < 0.2 or _path_distance(q) < 0.1 or not _is_free(q, 0.15):
				continue  # Not into the walls, the path, rocks, bushes or trunks.
			_queue("Grass", model, _xform(q, yaw, s), false)
			placed += 1


# --- Helpers ---------------------------------------------------------------------

## Footprint radius of a model at scale `s` (half its widest side), times
## `factor` (trees claim their trunk and lower crown, so crowns may touch).
static func _radius(path: String, s: float, factor: float = 1.0) -> float:
	var box := KitPiece.model_aabb(path)
	return maxf(box.size.x, box.size.z) * 0.5 * s * factor


## True if a circle at `p` with `radius` overlaps nothing placed so far.
func _is_free(p: Vector2, radius: float) -> bool:
	var cell := Vector2i(floori(p.x / TAKEN_CELL), floori(p.y / TAKEN_CELL))
	var reach := ceili((radius + TAKEN_MAX_RADIUS) / TAKEN_CELL)
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for other: Vector3 in _taken.get(cell + Vector2i(dx, dz), []):
				if p.distance_to(Vector2(other.x, other.y)) < radius + other.z:
					return false
	return true


## Takes the spot if it is free; returns whether it was.
func _claim(p: Vector2, radius: float) -> bool:
	if not _is_free(p, radius):
		return false
	var cell := Vector2i(floori(p.x / TAKEN_CELL), floori(p.y / TAKEN_CELL))
	if not _taken.has(cell):
		_taken[cell] = []
	(_taken[cell] as Array).append(Vector3(p.x, p.y, minf(radius, TAKEN_MAX_RADIUS)))
	return true


func _pick(rng: RandomNumberGenerator, names: Array) -> String:
	return NATURE % names[rng.randi() % names.size()]


## Upright, turned `yaw` around Y, uniform scale `s`, origin on the ground
## (the KayKit nature models have their roots / buried part below 0).
func _xform(p: Vector2, yaw: float, s: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, 0.0, p.y))


## Rocks also lean a little and sink in a bit.
func _rock_xform(rng: RandomNumberGenerator, p: Vector2, s: float) -> Transform3D:
	var tilt := Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
	var rock_basis := Basis.from_euler(tilt).scaled(Vector3.ONE * s)
	return Transform3D(rock_basis, Vector3(p.x, -0.08 * s, p.y))


## A detailed model as its own mesh nodes (casts shadows).
func _place(container: String, path: String, xform: Transform3D) -> void:
	var parent := _container(container)
	for part in KitPiece.model_parts(path):
		var instance := MeshInstance3D.new()
		instance.name = path.get_file().get_basename().trim_suffix("_Color1")
		instance.mesh = part["mesh"]
		instance.transform = xform * (part["xform"] as Transform3D)
		parent.add_child(instance)


## Collects instances of one model per container for a MultiMesh.
func _queue(container: String, path: String, xform: Transform3D, shadows: bool = false) -> void:
	var key := container + "|" + path
	if not _batches.has(key):
		_batches[key] = {"container": container, "path": path, "shadows": shadows, "xforms": []}
	(_batches[key]["xforms"] as Array).append(xform)


func _flush_batches() -> void:
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var xforms: Array = batch["xforms"]
		var path: String = batch["path"]
		var parent := _container(batch["container"])
		for part in KitPiece.model_parts(path):
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part["mesh"]
			multimesh.instance_count = xforms.size()
			var part_xform: Transform3D = part["xform"]
			for i in xforms.size():
				multimesh.set_instance_transform(i, (xforms[i] as Transform3D) * part_xform)
			var instance := MultiMeshInstance3D.new()
			instance.name = path.get_file().get_basename().trim_suffix("_Color1")
			instance.multimesh = multimesh
			if not batch["shadows"]:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(instance)
	_batches.clear()


## A generated grouping node, e.g. "Forest/Sector03" (created on demand).
func _container(container_path: String) -> Node3D:
	if _containers.has(container_path):
		return _containers[container_path]
	var parent: Node3D = self
	var slash := container_path.rfind("/")
	if slash >= 0:
		parent = _container(container_path.substr(0, slash))
	var node := Node3D.new()
	node.name = container_path.get_file()
	if parent == self:
		_add_generated(node)
	else:
		parent.add_child(node)
	_containers[container_path] = node
	return node


func _add_generated(node: Node) -> void:
	add_child(node)
	_generated.append(node)
