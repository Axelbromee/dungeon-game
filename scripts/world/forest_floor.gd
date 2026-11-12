@tool
class_name ForestFloor
extends Node3D
## Builds dungeon floor 1, a forest inside the magic dungeon, from code (like
## the guild's Outside): rebuilt live in the editor when a setting changes,
## generated nodes aren't saved, same seed = same floor.
##
## - Terrain: a low-poly heightmap (flat-shaded faces, one KayKit-palette
##   colour per face: grass, dirt paths, sandy shores, rock) with collision.
##   Gentle hills, rocky cliffs at the edges, a lake with shallow edges, a
##   stream valley, dirt paths, and a hole cut for each stair portal
##   (DungeonEntrance) so its pit shows.
## - Cave: cut into a rocky spur of the outer cliff wall. A cutting through
##   the cliff foot leads to an arched mouth in the cliff face; inside, narrow
##   passages open into wider chambers. Where the cave is, the ground mesh
##   is cut away and the cave brings its own floor, walls and ceiling, plus
##   an outer roof that follows the cliff's own heights, so the cliff has no
##   seams. Outline, ceiling and floor are roughened with noise; KayKit rocks,
##   rubble, glowing crystals and glowing mushrooms line the walls (a few soft
##   lights, one per chamber). The inside is on render layer 2, which the sun
##   skips; daylight seems to spill a few metres in from the mouth. The
##   `cave_darkness` area fades to a dark ambient light inside.
## - Water (lake + stream) with collision on layer 5 only (spawn areas avoid
##   it; the player wades through).
## - Nature: KayKit trees, bushes, rocks, logs, grass and reeds, plus small
##   flowers, as MultiMeshes in chunks (each chunk drawn only up to its own
##   distance). Nothing overlaps: every piece claims its footprint. Rocks,
##   logs and bushes lean with the slope. Trees, big rocks and logs collide
##   (layer 1); bushes and small rocks only block spawn areas (layer 6).
## - Light shafts slanting down from the sun into the forest.
## - Snapping: every direct child of the `snap_roots` (portals, spawn points,
##   spawn areas) is moved onto the ground. Optional meta "snap_offset"
##   (float) lifts it; meta "no_snap" skips it.
##
## Coordinates: the floor is centred on this node; +Z is south.

const NATURE := "res://KayKit/Assets4/gltf/%s_Color1.gltf"
const RESOURCE := "res://KayKit/Assets3/gltf/%s.gltf"
const TERRAIN_MATERIAL := "res://materials/world/floor1_terrain.tres"
const WATER_MATERIAL := "res://materials/world/water.tres"
const WATER_LAYER := 16  # Physics layer 5.
const SCENERY_LAYER := 32  # Physics layer 6: only spawn areas look at it.
## Render layer 2: the cave's inside and everything in it. The sun's cull mask
## leaves this layer out, so only the cave's own lights and glow light it.
const CAVE_RENDER_LAYER := 2
## MultiMesh groups that live inside the cave (drawn on CAVE_RENDER_LAYER).
const CAVE_GROUPS := ["CaveRocks", "Crystals", "GlowPlants"]
## How far into the cave daylight seems to spill (metres from the mouth).
const CAVE_SPILL_DEPTH := 8.0

const TREES := ["Tree_1_A", "Tree_1_B", "Tree_1_C", "Tree_2_B", "Tree_2_C", "Tree_2_D", "Tree_3_B", "Tree_4_B", "Tree_4_C"]
const TREES_BARE := ["Tree_Bare_1_C", "Tree_Bare_2_B"]
const BUSHES := ["Bush_1_C", "Bush_1_E", "Bush_2_C", "Bush_3_B", "Bush_4_C"]
const ROCKS_SMALL := ["Rock_1_D", "Rock_2_C", "Rock_3_E", "Rock_3_G"]
const ROCKS_BIG := ["Rock_1_J", "Rock_2_E", "Rock_3_M", "Rock_3_Q"]
## Tall rock spires for the cave.
const ROCKS_SPIRE := ["Rock_1_N", "Rock_1_O", "Rock_1_P"]
const GRASS := ["Grass_1_B", "Grass_2_B", "Grass_1_C"]
const REEDS := ["Grass_2_C", "Grass_2_D"]
const LOGS := ["Wood_Log_A", "Wood_Log_B"]
## KayKit-style palette (flat colours like the KayKit atlases).
const GRASS_COLORS: Array[Color] = [Color(0.38, 0.65, 0.28), Color(0.33, 0.6, 0.26), Color(0.42, 0.69, 0.3)]
const DIRT_COLOR := Color(0.74, 0.55, 0.38)
const SAND_COLOR := Color(0.86, 0.77, 0.56)
const ROCK_COLOR := Color(0.56, 0.6, 0.63)
const CAVE_FLOOR_COLOR := Color(0.44, 0.47, 0.52)
const CAVE_INSIDE_COLOR := Color(0.46, 0.49, 0.55)
## Low parts of the cave walls (KayKit rocks run from light on top to dark below).
const CAVE_DEEP_COLOR := Color(0.3, 0.33, 0.38)
## Mid-sized KayKit rocks that line the cave walls.
const ROCKS_WALL := ["Rock_1_G", "Rock_1_H", "Rock_2_D", "Rock_3_G", "Rock_3_J", "Rock_3_K"]
const FLOWER_COLORS: Array[Color] = [
	Color(0.96, 0.55, 0.75), Color(1.0, 0.85, 0.35), Color(0.97, 0.96, 0.92),
	Color(0.65, 0.5, 0.9), Color(0.45, 0.8, 0.95),
]
## Trees claim this fraction of their crown width (trunk and lower crown):
## crowns may touch, but trunks, rocks, logs and bushes never overlap.
const TREE_FOOTPRINT := 0.45
const TAKEN_CELL := 4.0
const TAKEN_MAX_RADIUS := 6.0

@export var layout_seed: int = 11

@export_group("Terrain")
## Width and depth in metres (square, centred on this node).
@export var size: float = 200.0
## Distance between terrain vertices.
@export var cell: float = 1.0
@export var hill_height: float = 5.0
@export var hill_frequency: float = 0.012
## Width of the rising rim at the map edge, and how high the cliffs get.
@export var edge_band: float = 14.0
@export var cliff_height: float = 16.0

@export_group("Places")
## Stair portals (DungeonEntrance). The terrain is flattened around them and
## a hole is cut for their footprint.
@export var portals: Array[NodePath] = [NodePath("../Portals/ArrivalStairs"), NodePath("../Portals/ExitStairs")]
## The first portal's clearing stays free of trees.
@export var clearing_radius: float = 18.0
@export var lake_center: Vector2 = Vector2(-55, 25)
@export var lake_radius: float = 16.0
@export var lake_depth: float = 2.2
@export var water_level: float = 0.0
## Stream from the lake; it ends under the edge cliffs.
@export var stream: PackedVector2Array = PackedVector2Array([Vector2(-52, 38), Vector2(-45, 50), Vector2(-47, 63), Vector2(-40, 74), Vector2(-44, 94)])
@export var stream_half_width: float = 1.4
## Water level drop per metre along the stream.
@export var stream_drop: float = 0.025
@export var plain_center: Vector2 = Vector2(50, 35)
@export var plain_radius: float = 30.0
## Dirt paths (each a line of points).
@export var paths: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 67), Vector2(6, 58), Vector2(22, 46), Vector2(38, 38)]),
	PackedVector2Array([Vector2(6, 58), Vector2(-10, 48), Vector2(-26, 34), Vector2(-37, 26)]),
	PackedVector2Array([Vector2(6, 58), Vector2(10, 30), Vector2(14, 5), Vector2(2, -22), Vector2(-14, -44), Vector2(-34, -62), Vector2(-56, -64)]),
	PackedVector2Array([Vector2(14, 5), Vector2(30, -20), Vector2(40, -40)]),
]

@export_group("Cave")
## The rocky spur of the outer cliff wall the cave is cut into: this area
## (x, z, width, depth) rises `cave_cliff_height` above the ground, with steep
## rock sides `cave_cliff_slope` metres wide.
@export var cave_cliff: Rect2 = Rect2(5, -100, 85, 45)
@export var cave_cliff_height: float = 24.0
@export var cave_cliff_slope: float = 8.0
## Chambers and passages, each [x1, z1, x2, z2, radius, ceiling height]:
## a capsule from point 1 to point 2 (the same point twice = a round chamber).
## The outline is roughened with noise, so these are only the rough shape.
@export var cave_shapes: Array[PackedFloat32Array] = [
	PackedFloat32Array([40, -44, 40, -62, 3.2, 4.0]),   # Cutting and entrance tunnel.
	PackedFloat32Array([40, -68, 40, -68, 6.5, 6.0]),   # Entry hall.
	PackedFloat32Array([40, -68, 47, -77, 3.0, 4.0]),   # Passage to the main chamber.
	PackedFloat32Array([50, -83, 50, -83, 12.0, 9.0]),  # Main chamber.
	PackedFloat32Array([50, -83, 68, -78, 3.0, 4.0]),   # Passage east.
	PackedFloat32Array([71, -77, 71, -77, 8.0, 7.0]),   # East chamber.
	PackedFloat32Array([50, -83, 30, -80, 2.8, 3.8]),   # Passage west.
	PackedFloat32Array([26, -79, 26, -79, 6.0, 6.0]),   # West alcove.
]
## The cave's mouth in the cliff face: south of this Z the cave is an open
## cutting through the cliff foot (keep it a whole number of metres); X is
## the middle of the mouth.
@export var cave_mouth: Vector2 = Vector2(40, -54)
## How lumpy the rock is: walls wandering in and out, bumps and hanging
## rock on the ceiling, an uneven floor (0 = smooth).
@export_range(0.0, 2.0) var cave_roughness: float = 1.0

@export_group("Nature")
@export_range(0.0, 1.0) var forest_density: float = 0.6
@export_range(0.0, 1.0) var grass_density: float = 1.0
## Grid cell for tree candidates (smaller = more trees).
@export var tree_spacing: float = 3.2
@export var tree_scale: Vector2 = Vector2(1.3, 2.1)
@export var light_shafts: int = 14

@export_group("Scene")
@export var nature_root: NodePath = NodePath("../Nature")
@export var water_root: NodePath = NodePath("../Water")
@export var shafts_root: NodePath = NodePath("../Lighting/LightShafts")
## Area3D (an AmbienceZone) that gets the cave's shapes, to dim the light inside.
@export var cave_darkness: NodePath = NodePath("../Lighting/CaveDarkness")
@export var sun: NodePath = NodePath("../Lighting/Sun")
## Direct children of these are put on the ground.
@export var snap_roots: Array[NodePath] = [NodePath("../Portals"), NodePath("../Spawns")]

@export_tool_button("Rebuild") var rebuild_action := _rebuild
@export_tool_button("Snap to ground") var snap_action := _snap_nodes

var _n: int = 0
var _heights := PackedFloat32Array()
## Per-vertex weights: r = dirt, g = rock, b = sand (wet), a = cave floor.
var _weights := PackedColorArray()
var _noise: FastNoiseLite
var _detail: FastNoiseLite
var _pads: Array[Dictionary] = []
var _holes: Array[Dictionary] = []
var _cave_level: float = 0.0
## Cliff height before the cave is cut out (the cave's outer roof uses it).
var _tops := PackedFloat32Array()
## 1 where a vertex is inside the cave or its cutting.
var _inside := PackedByteArray()
var _cave_box := Rect2()
## Built meshes used by the MultiMesh batches (flowers, crystals, mushrooms).
var _custom_meshes: Dictionary = {}
var _generated: Array[Node] = []
var _containers: Dictionary = {}
var _batches: Dictionary = {}
var _taken: Dictionary = {}
var _colliders: StaticBody3D
var _scenery: StaticBody3D
var _signature: String = ""


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		set_process(false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _make_signature() != _signature:
		_rebuild()


## Terrain height (metres, world Y) at world X/Z.
func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var local := Vector2(x - global_position.x, z - global_position.z)
	if _on_cave_floor(local):
		return _cave_floor(local) + global_position.y
	var fx := (x - global_position.x + size * 0.5) / cell
	var fz := (z - global_position.z + size * 0.5) / cell
	var ix := clampi(floori(fx), 0, _n - 2)
	var iz := clampi(floori(fz), 0, _n - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var top := lerpf(_heights[iz * _n + ix], _heights[iz * _n + ix + 1], tx)
	var bottom := lerpf(_heights[(iz + 1) * _n + ix], _heights[(iz + 1) * _n + ix + 1], tx)
	return lerpf(top, bottom, tz) + global_position.y


func _make_signature() -> String:
	var parts := PackedStringArray()
	for property in get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR and property["type"] != TYPE_CALLABLE:
			parts.append(str(get(property["name"])))
	return "|".join(parts)


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

	_noise = FastNoiseLite.new()
	_noise.seed = layout_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = hill_frequency
	_noise.fractal_octaves = 3
	_detail = FastNoiseLite.new()
	_detail.seed = layout_seed + 7
	_detail.frequency = 0.08

	_cave_box = _cave_bounds(3.0)
	_custom_meshes.clear()
	_collect_pads()
	_build_heights()
	_build_terrain()
	_build_cave()
	_snap_nodes()
	_build_water()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	_scatter_nature(rng)
	_flush_batches()
	_build_light_shafts(rng)


# --- Shape of the land --------------------------------------------------------

## Flat pads around each portal (with its hole).
func _collect_pads() -> void:
	_pads.clear()
	_holes.clear()
	for i in portals.size():
		var portal := get_node_or_null(portals[i]) as Node3D
		if portal == null:
			continue
		var centre := _to_local_xz(portal.global_position)
		var footprint: Vector2 = portal.get("footprint") if "footprint" in portal else Vector2(8, 10)
		var half := footprint * 0.5
		var level := _raw(centre).x
		_pads.append({"centre": centre, "radius": half.length() + 1.0, "blend": 10.0 if i == 0 else 6.0, "height": level})
		_holes.append({"inverse": (global_transform.affine_inverse() * portal.global_transform).affine_inverse(), "half": half})
	# The cave floor is level with the ground where its cutting begins.
	_cave_level = _raw(cave_mouth + Vector2(0, 14)).x


## Height and weights before the pads: Vector4(h, dirt, rock, sand).
func _raw(p: Vector2) -> Vector4:
	var h := (_noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5) * hill_height + _detail.get_noise_2d(p.x, p.y) * 0.4
	var dirt := 0.0
	var rock := 0.0
	var sand := 0.0

	# Meadow: much gentler.
	var plain_t := 1.0 - smoothstep(plain_radius * 0.6, plain_radius, p.distance_to(plain_center))
	h = lerpf(h, h * 0.3 + 0.9, plain_t)

	# Lake: a bowl with shallow edges, banks kept above the water.
	var dl := p.distance_to(lake_center) + _detail.get_noise_2d(p.x * 0.5, p.y * 0.5) * 2.0
	if dl < lake_radius + 12.0:
		var bed := water_level - 0.15 - lake_depth * (1.0 - pow(clampf(dl / lake_radius, 0.0, 1.0), 2.0))
		var shore := lerpf(water_level + 0.3, maxf(h, water_level + 0.3), smoothstep(lake_radius + 1.0, lake_radius + 12.0, dl))
		var wet := 1.0 - smoothstep(lake_radius - 3.0, lake_radius + 1.0, dl)
		h = lerpf(shore, bed, wet)
		sand = maxf(sand, 1.0 - smoothstep(lake_radius + 1.0, lake_radius + 3.5, dl))

	# Stream: a shallow channel in a small valley, water dropping slowly.
	var sp := _project(p, stream)
	var w := stream_half_width
	if sp.x < w + 9.0:
		var surface := water_level - sp.y * stream_drop
		var bed := surface - 0.15 - 0.45 * (1.0 - pow(clampf(sp.x / w, 0.0, 1.0), 2.0))
		var bank := lerpf(surface + 0.25, maxf(h, surface + 0.25), smoothstep(w + 0.8, w + 9.0, sp.x))
		h = lerpf(bank, bed, 1.0 - smoothstep(w - 0.6, w + 0.8, sp.x))
		sand = maxf(sand, 1.0 - smoothstep(w + 0.3, w + 1.6, sp.x))

	# Paths: worn dirt, slightly sunk.
	var pd := _path_distance(p)
	var path_t := 1.0 - smoothstep(1.1, 2.4, pd + _detail.get_noise_2d(p.x * 1.3, p.y * 1.3) * 0.5)
	dirt = maxf(dirt, path_t)
	h -= 0.12 * path_t

	# Edge: rising rocky cliffs so nobody leaves, and the rocky spur the cave
	# is cut into.
	var edge := size * 0.5 - maxf(absf(p.x), absf(p.y))
	var cliff := 1.0 - smoothstep(0.0, edge_band, edge)
	var spur_d := _rect_distance(p, cave_cliff) + _detail.get_noise_2d(p.x * 0.3 + 70.0, p.y * 0.3) * 3.0
	var spur := 1.0 - smoothstep(0.0, cave_cliff_slope, spur_d)
	var rocky := maxf(cliff, spur)
	h += maxf(pow(cliff, 1.6) * cliff_height, pow(spur, 1.3) * cave_cliff_height) \
		+ rocky * _detail.get_noise_2d(p.x * 0.6, p.y * 0.6) * 3.0
	rock = maxf(rock, smoothstep(0.3, 0.65, rocky))
	return Vector4(h, dirt, rock, sand)


func _build_heights() -> void:
	_n = int(round(size / cell)) + 1
	_heights.resize(_n * _n)
	_tops.resize(_n * _n)
	_inside.resize(_n * _n)
	_weights.resize(_n * _n)
	for iz in _n:
		for ix in _n:
			var p := _grid_point(ix, iz)
			var v := _raw(p)
			var h := v.x
			var dirt := v.y
			for pad in _pads:
				var t := 1.0 - smoothstep(pad["radius"], pad["radius"] + pad["blend"], p.distance_to(pad["centre"]))
				h = lerpf(h, pad["height"], t)
				dirt = maxf(dirt, t * 0.6)
			var i := iz * _n + ix
			_tops[i] = h
			_inside[i] = 0
			var cave := 0.0
			if _cave_box.has_point(p) and _cave_sdf(p) < 0.0:
				# Cave floor (inside the mouth) or the floor of the cutting.
				_inside[i] = 1
				h = _cave_floor(p)
				if p.y <= cave_mouth.y:
					cave = 1.0
				else:
					dirt = maxf(dirt, 0.7)
			_heights[i] = h
			_weights[i] = Color(dirt, v.z, v.w, cave)


## Flat-shaded terrain: every triangle gets its own normal and one palette
## colour, like the KayKit low-poly models.
func _build_terrain() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in _n - 1:
		for ix in _n - 1:
			var centre := _grid_point(ix, iz) + Vector2(cell, cell) * 0.5
			if _in_hole(centre) or _is_cave_quad(ix, iz):
				continue
			var a := iz * _n + ix
			var b := a + 1
			var c := a + _n
			var d := c + 1
			# Clockwise seen from above (Godot's front faces).
			for tri in [[a, b, c], [b, d, c]]:
				var p0 := _vertex(tri[0])
				var p1 := _vertex(tri[1])
				var p2 := _vertex(tri[2])
				var normal := (p2 - p0).cross(p1 - p0).normalized()
				var weights: Color = (_weights[tri[0]] + _weights[tri[1]] + _weights[tri[2]]) / 3.0
				var color := _ground_color(weights, normal, (p0 + p1 + p2) / 3.0)
				for point in [p0, p1, p2]:
					vertices.append(point)
					normals.append(normal)
					colors.append(color)
	var instance := MeshInstance3D.new()
	instance.name = "Ground"
	instance.mesh = _mesh(vertices, normals, colors)
	_add_generated(instance, self)
	_add_generated(_trimesh_body("GroundBody", vertices, 1), self)


@warning_ignore("integer_division")
func _vertex(index: int) -> Vector3:
	var p := _grid_point(index % _n, index / _n)
	return Vector3(p.x, _heights[index], p.y)


## One palette colour for a terrain face.
func _ground_color(weights: Color, normal: Vector3, centre: Vector3) -> Color:
	var shade := 1.0 + (_hash(centre) - 0.5) * 0.06  # Faint facet variation.
	if weights.a > 0.5:
		return CAVE_FLOOR_COLOR * shade
	if weights.g > 0.5 or normal.y < 0.68:
		return ROCK_COLOR * shade
	if weights.b > 0.5:
		return SAND_COLOR * shade
	if weights.r > 0.5:
		return DIRT_COLOR * shade
	var tone := _noise.get_noise_2d(centre.x * 3.0 + 900.0, centre.z * 3.0)
	var index := 0 if tone < -0.15 else (1 if tone < 0.2 else 2)
	return GRASS_COLORS[index] * shade


static func _hash(p: Vector3) -> float:
	return fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0)


func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, load(TERRAIN_MATERIAL))
	return mesh


func _trimesh_body(body_name: String, faces: PackedVector3Array, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = layer
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return body


func _in_hole(p: Vector2) -> bool:
	for hole in _holes:
		var local: Vector3 = (hole["inverse"] as Transform3D) * Vector3(p.x, 0.0, p.y)
		var half: Vector2 = hole["half"]
		if absf(local.x) < half.x and absf(local.z) < half.y:
			return true
	return false


func _grid_point(ix: int, iz: int) -> Vector2:
	return Vector2(-size * 0.5 + ix * cell, -size * 0.5 + iz * cell)


## Distance to a line of points and how far along it: Vector2(distance, along).
static func _project(p: Vector2, line: PackedVector2Array) -> Vector2:
	var best := INF
	var best_along := 0.0
	var along := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var ab := line[i + 1] - a
		var length := ab.length()
		var t := clampf((p - a).dot(ab) / maxf(length * length, 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_along = along + t * length
		along += length
	return Vector2(best, best_along)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _path_distance(p: Vector2) -> float:
	var best := INF
	for line in paths:
		best = minf(best, _project(p, line).x)
	return best


func _to_local_xz(world: Vector3) -> Vector2:
	var local := global_transform.affine_inverse() * world
	return Vector2(local.x, local.z)


# --- Cave -------------------------------------------------------------------

## Noise that pushes the cave's outline in and out (metres), so the walls
## wander instead of following the round shapes.
## Calmer near the mouth, so the opening stays a clean arch.
func _cave_warp(p: Vector2) -> float:
	var calm := lerpf(0.3, 1.0, smoothstep(2.0, 10.0, p.distance_to(cave_mouth)))
	return (_detail.get_noise_2d(p.x * 0.6 + 300.0, p.y * 0.6) * 2.2
		+ _detail.get_noise_2d(p.x * 2.0 - 150.0, p.y * 2.0) * 0.6) * cave_roughness * calm


## How far inside one shape a point is (negative outside). Narrow passages
## get less of the warp, so they never pinch shut.
static func _shape_inside(p: Vector2, shape: PackedFloat32Array, warp: float) -> float:
	var d := _segment_distance(p, Vector2(shape[0], shape[1]), Vector2(shape[2], shape[3]))
	return shape[4] - d + warp * clampf(shape[4] / 6.0, 0.35, 1.0)


## Signed distance to a rectangle (negative inside).
static func _rect_distance(p: Vector2, rect: Rect2) -> float:
	var centre := rect.get_center()
	var q := Vector2(absf(p.x - centre.x), absf(p.y - centre.y)) - rect.size * 0.5
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


## Area around all cave shapes, grown by `margin`.
func _cave_bounds(margin: float) -> Rect2:
	var box := Rect2()
	var first := true
	for shape in cave_shapes:
		if shape.size() < 6:
			continue
		var r: float = shape[4] + margin
		var part := Rect2(minf(shape[0], shape[2]) - r, minf(shape[1], shape[3]) - r,
			absf(shape[2] - shape[0]) + r * 2.0, absf(shape[3] - shape[1]) + r * 2.0)
		box = part if first else box.merge(part)
		first = false
	return box


## Uneven cave floor; level in the cutting and at the mouth, so it meets the
## ground outside.
func _cave_floor(p: Vector2) -> float:
	var bumps := _detail.get_noise_2d(p.x * 1.1 + 210.0, p.y * 1.1) * 0.5 + _detail.get_noise_2d(p.x * 2.6, p.y * 2.6 - 90.0) * 0.2
	return _cave_level + bumps * smoothstep(2.0, 10.0, cave_mouth.y - p.y) * cave_roughness


## True on the cave's own floor (inside the mouth), where heights come from
## _cave_floor() rather than the terrain grid.
func _on_cave_floor(p: Vector2) -> bool:
	return p.y < cave_mouth.y and _cave_box.has_point(p) and _cave_sdf(p) < 0.5


## A terrain quad the cave replaces: inside the mouth with a corner in the cave.
func _is_cave_quad(ix: int, iz: int) -> bool:
	if _inside.is_empty() or _grid_point(ix, iz).y + cell * 0.5 >= cave_mouth.y:
		return false
	var a := iz * _n + ix
	return _inside[a] == 1 or _inside[a + 1] == 1 or _inside[a + _n] == 1 or _inside[a + _n + 1] == 1


## Direction into the cave (away from the nearest wall).
func _cave_inward(p: Vector2) -> Vector2:
	var g := Vector2(_cave_sdf(p + Vector2(0.5, 0)) - _cave_sdf(p - Vector2(0.5, 0)),
		_cave_sdf(p + Vector2(0, 0.5)) - _cave_sdf(p - Vector2(0, 0.5)))
	return -g.normalized() if g.length() > 0.0001 else Vector2(0, 1)


## Signed distance to the cave's outline (negative inside).
func _cave_sdf(p: Vector2) -> float:
	var warp := _cave_warp(p)
	var best := -INF
	for shape in cave_shapes:
		if shape.size() >= 6:
			best = maxf(best, _shape_inside(p, shape, warp))
	return -best


## Ceiling height above the floor (0 outside the cave). Each chamber or
## passage is a rounded vault: steep rock walls curving over into the
## ceiling, its height varying along the way, with lumps and hanging rock.
func _cave_height(p: Vector2) -> float:
	var warp := _cave_warp(p)
	var best := 0.0
	var deepest := 0.0
	for shape in cave_shapes:
		if shape.size() < 6:
			continue
		var inside := _shape_inside(p, shape, warp)
		if inside <= 0.0:
			continue
		deepest = maxf(deepest, inside)
		var fall := clampf(shape[4] * 0.55, 2.5, 7.0)
		var t := clampf(inside / fall, 0.0, 1.0)
		var top: float = shape[5] * (1.0 + _detail.get_noise_2d(p.x * 0.35 + 40.0, p.y * 0.35) * 0.25 * cave_roughness)
		best = maxf(best, top * (1.0 - pow(1.0 - t, 2.2)))
	if best <= 0.0:
		return 0.0
	# Lumpy rock.
	var bumps := _detail.get_noise_2d(p.x * 1.2 + 77.0, p.y * 1.2) * 0.9 + _detail.get_noise_2d(p.x * 3.0 - 20.0, p.y * 3.0) * 0.35
	best += bumps * minf(best * 0.35, 1.2) * cave_roughness
	# Hanging rock where the ceiling is high.
	var hang := _detail.get_noise_2d(p.x * 2.2 + 500.0, p.y * 2.2)
	if hang > 0.45:
		best -= (hang - 0.45) * 6.0 * smoothstep(3.5, 7.0, best) * cave_roughness
	# Always head room away from the walls.
	if deepest > 1.5:
		best = maxf(best, 2.6)
	return maxf(best, 0.05)


## The cave: an outer rocky shell (the mound seen from the forest) and an
## inner shell (the cave's walls and ceiling), both meeting the ground at the
## cave's edge, cut open at the mouth with a rim between them.
func _build_cave() -> void:
	if cave_shapes.is_empty():
		return
	var half := size * 0.5
	var x0 := clampi(floori((_cave_box.position.x + half) / cell), 0, _n - 2)
	var x1 := clampi(ceili((_cave_box.end.x + half) / cell), 1, _n - 1)
	var z0 := clampi(floori((_cave_box.position.y + half) / cell), 0, _n - 2)
	var mouth_row := clampi(roundi((cave_mouth.y + half) / cell), 1, _n - 1)

	# Per vertex: the cave floor and the ceiling's height above it.
	var floors := {}
	var ceilings := {}
	for iz in range(z0, mouth_row + 1):
		for ix in range(x0, x1 + 1):
			var p := _grid_point(ix, iz)
			var i := iz * _n + ix
			floors[i] = _cave_floor(p)
			ceilings[i] = _cave_height(p) if _inside[i] == 1 else 0.0

	var inside := MeshData.new()
	var outside := MeshData.new()
	for iz in range(z0, mouth_row):
		for ix in range(x0, x1):
			if not _is_cave_quad(ix, iz):
				continue
			var a := iz * _n + ix
			var b := a + 1
			var c := a + _n
			var d := c + 1
			for tri in [[a, b, c], [b, d, c]]:
				var ground: Array[Vector3] = []
				var under: Array[Vector3] = []
				var over: Array[Vector3] = []
				var rise := 0.0
				for k in 3:
					var v: Vector3 = _vertex(tri[k])
					var fl: float = floors[tri[k]]
					var hc: float = ceilings[tri[k]]
					ground.append(Vector3(v.x, fl, v.z))
					under.append(Vector3(v.x, fl + hc, v.z))
					over.append(Vector3(v.x, _tops[tri[k]], v.z))
					rise += hc / 3.0
				# Outer roof: the cliff surface over the cave, coloured like the
				# terrain around it, so the two meet without a seam.
				var normal := (over[2] - over[0]).cross(over[1] - over[0]).normalized()
				var weights: Color = (_weights[tri[0]] + _weights[tri[1]] + _weights[tri[2]]) / 3.0
				weights.a = 0.0
				_add_tri(outside, over[0], over[1], over[2],
					_ground_color(weights, normal, (over[0] + over[1] + over[2]) / 3.0), 0.0)
				if rise <= 0.0:
					continue  # Floor and ceiling meet here: nothing to see inside.
				# Floor (faces up) and walls / ceiling (face down and in).
				var spill := _cave_spill((ground[0] + ground[1] + ground[2]) / 3.0)
				_add_tri(inside, ground[0], ground[1], ground[2], CAVE_FLOOR_COLOR * spill)
				_add_tri(inside, under[0], under[2], under[1],
					CAVE_DEEP_COLOR.lerp(CAVE_INSIDE_COLOR, clampf(rise / 6.0, 0.0, 1.0)) * spill)

	# The cliff face above the mouth: from the arch up to the cliff surface.
	for ix in range(x0, x1):
		if not _is_cave_quad(ix, mouth_row - 1):
			continue
		var a := mouth_row * _n + ix
		var b := a + 1
		var pa := _vertex(a)
		var pb := _vertex(b)
		var ia := Vector3(pa.x, floors[a] + ceilings[a], pa.z)
		var ib := Vector3(pb.x, floors[b] + ceilings[b], pb.z)
		var oa := Vector3(pa.x, maxf(_tops[a], ia.y), pa.z)
		var ob := Vector3(pb.x, maxf(_tops[b], ib.y), pb.z)
		_add_tri(outside, oa, ob, ia, ROCK_COLOR)
		_add_tri(outside, ob, ib, ia, ROCK_COLOR)

	var cave := Node3D.new()
	cave.name = "Cave"
	_add_generated(cave, self)
	var outer_mesh := MeshInstance3D.new()
	outer_mesh.name = "Cliff"
	outer_mesh.mesh = _mesh(outside.vertices, outside.normals, outside.colors)
	cave.add_child(outer_mesh)
	var inner_mesh := MeshInstance3D.new()
	inner_mesh.name = "Inside"
	inner_mesh.layers = CAVE_RENDER_LAYER  # No sunlight inside.
	inner_mesh.mesh = _mesh(inside.vertices, inside.normals, inside.colors)
	cave.add_child(inner_mesh)
	var faces := PackedVector3Array(inside.vertices)
	faces.append_array(outside.vertices)
	cave.add_child(_trimesh_body("CaveBody", faces, 1))

	# A few soft lights, one per chamber, tinted like the crystals.
	var light_index := 0
	for shape in cave_shapes:
		if shape.size() < 6 or shape[0] != shape[2] or shape[1] != shape[3] or shape[1] >= cave_mouth.y:
			continue
		var at := Vector2(shape[0], shape[1])
		var light := OmniLight3D.new()
		light.name = "GlowLight%d" % light_index
		light.light_color = Color(0.5, 0.85, 1.0) if light_index % 2 == 0 else Color(0.72, 0.55, 1.0)
		light.light_energy = 0.9
		light.omni_range = shape[4] + 4.0
		light.omni_attenuation = 1.4
		light.position = Vector3(at.x, _cave_floor(at) + minf(shape[5] * 0.45, 3.5), at.y)
		cave.add_child(light)
		light_index += 1
	_build_cave_darkness()


## Triangles being collected for one flat-shaded mesh.
class MeshData:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	## A triangle with its own face normal (front = clockwise from the viewer).
	func tri(p0: Vector3, p1: Vector3, p2: Vector3, color: Color) -> void:
		var normal := (p2 - p0).cross(p1 - p0).normalized()
		for point in [p0, p1, p2]:
			vertices.append(point)
			normals.append(normal)
			colors.append(color)


## Adds a triangle in a palette colour with a faint per-face variation.
static func _add_tri(data: MeshData, p0: Vector3, p1: Vector3, p2: Vector3, base: Color, variation: float = 0.08) -> void:
	data.tri(p0, p1, p2, base * (1.0 + (_hash((p0 + p1 + p2) / 3.0) - 0.5) * variation))


## Colour boost for the cave's inside near the mouth: daylight seems to spill
## in and fade out over the first CAVE_SPILL_DEPTH metres.
func _cave_spill(at: Vector3) -> float:
	return lerpf(1.6, 1.0, smoothstep(0.0, CAVE_SPILL_DEPTH, cave_mouth.y - at.z))


## Gives the darkness area one shape per chamber / passage (inside the mouth).
func _build_cave_darkness() -> void:
	var zone := get_node_or_null(cave_darkness) as Area3D
	if zone == null:
		return
	for shape in cave_shapes:
		if shape.size() < 6:
			continue
		var a := Vector2(shape[0], shape[1])
		var b := Vector2(shape[2], shape[3])
		# Keep the zone inside the mouth.
		# The darkness starts a few metres in, after the daylight spill.
		a.y = minf(a.y, cave_mouth.y - 3.0)
		b.y = minf(b.y, cave_mouth.y - 3.0)
		var collider := CollisionShape3D.new()
		var centre := (a + b) * 0.5
		if a.distance_to(b) < 0.1:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = shape[4] + 2.5
			cylinder.height = shape[5] + 4.0
			collider.shape = cylinder
		else:
			var box := BoxShape3D.new()
			box.size = Vector3(shape[4] * 2.0 + 5.0, shape[5] + 4.0, a.distance_to(b))
			collider.shape = box
			collider.rotation.y = atan2(b.x - a.x, b.y - a.y)
		collider.position = Vector3(centre.x, _cave_level + shape[5] * 0.5 + 1.0, centre.y)
		_add_generated(collider, zone)


# --- Snapping ---------------------------------------------------------------

## Puts the direct children of the snap roots on the ground.
func _snap_nodes() -> void:
	if _heights.is_empty():
		return
	for root_path in snap_roots:
		var root := get_node_or_null(root_path)
		if root == null:
			continue
		for child in root.get_children():
			var node := child as Node3D
			if node == null or node.has_meta("no_snap"):
				continue
			var offset := float(node.get_meta("snap_offset", 0.0))
			var pos := node.global_position
			pos.y = height_at(pos.x, pos.z) + offset
			node.global_position = pos


# --- Water --------------------------------------------------------------------

func _build_water() -> void:
	var root := _root(water_root)
	var material := load(WATER_MATERIAL) as Material

	var lake := MeshInstance3D.new()
	lake.name = "Lake"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (lake_radius + 3.0) * 2.0
	plane.subdivide_width = 16
	plane.subdivide_depth = 16
	lake.mesh = plane
	lake.material_override = material
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lake.position = Vector3(lake_center.x, water_level, lake_center.y)
	_add_generated(lake, root)
	var lake_body := _water_body("LakeSurface", root)
	var disc := CylinderShape3D.new()
	disc.radius = lake_radius + 1.0
	disc.height = 0.2
	var disc_collider := CollisionShape3D.new()
	disc_collider.shape = disc
	disc_collider.position = Vector3(lake_center.x, water_level, lake_center.y)
	lake_body.add_child(disc_collider)

	# Stream ribbon from the lake shore on, following the water level.
	var total := _line_length(stream)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var started := false
	var along := 0.0
	while along <= total:
		var at := _point_along(stream, along)
		var ahead := _point_along(stream, minf(along + 0.5, total)) - _point_along(stream, maxf(along - 0.5, 0.0))
		var side := Vector2(-ahead.y, ahead.x).normalized() * (stream_half_width + 0.6)
		var y := water_level - along * stream_drop
		var l := Vector3(at.x - side.x, y, at.y - side.y)
		var r := Vector3(at.x + side.x, y, at.y + side.y)
		if at.distance_to(lake_center) > lake_radius + 1.5:
			if started:
				for v in [prev_l, prev_r, r, prev_l, r, l]:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
					faces.append(v)
			started = true
		prev_l = l
		prev_r = r
		along += 1.0
	if faces.is_empty():
		return
	var ribbon := MeshInstance3D.new()
	ribbon.name = "Stream"
	ribbon.mesh = st.commit()
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(ribbon, root)
	var stream_body := _water_body("StreamSurface", root)
	var stream_shape := ConcavePolygonShape3D.new()
	stream_shape.set_faces(faces)
	stream_shape.backface_collision = true
	var stream_collider := CollisionShape3D.new()
	stream_collider.shape = stream_shape
	stream_body.add_child(stream_collider)


## Water surfaces are only on layer 5: nothing collides with them, but spawn
## areas see them and skip spots under water.
func _water_body(body_name: String, root: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = WATER_LAYER
	body.collision_mask = 0
	_add_generated(body, root)
	return body


static func _line_length(line: PackedVector2Array) -> float:
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	return total


static func _point_along(line: PackedVector2Array, distance: float) -> Vector2:
	var left := distance
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		if left <= length:
			return line[i].lerp(line[i + 1], left / maxf(length, 0.0001))
		left -= length
	return line[line.size() - 1]


# --- Nature -------------------------------------------------------------------

## What grows where: "" = nothing, else a zone name.
func _zone(p: Vector2) -> StringName:
	for pad in _pads:
		if p.distance_to(pad["centre"]) < pad["radius"] + 1.0:
			return &""
	if _in_hole(p):
		return &""
	var cave := _cave_sdf(p) if _cave_box.has_point(p) else INF
	if cave < 0.0:
		if p.y < cave_mouth.y - 0.5:
			if cave < -3.5:
				return &"cave"
			return &"cave_wall" if cave < -0.2 else &""
		return &"cutting" if cave > -2.0 and p.y > cave_mouth.y + 0.5 else &""
	if cave < 1.0:
		return &""  # The cave's walls and the ground right at its edge.
	if cave < 5.0 and p.y > cave_mouth.y:
		return &"cave_edge"  # Around the cutting: rocks and low plants only.
	var dl := p.distance_to(lake_center)
	if dl < lake_radius + 1.0:
		return &"lake"
	if _project(p, stream).x < stream_half_width + 1.0:
		return &"stream"
	if _path_distance(p) < 2.0:
		return &"path"
	var edge := size * 0.5 - maxf(absf(p.x), absf(p.y))
	if edge < edge_band:
		return &"cliff"
	if not _pads.is_empty() and p.distance_to(_pads[0]["centre"]) < clearing_radius:
		return &"clearing"
	if p.distance_to(plain_center) < plain_radius:
		return &"plain"
	return &"forest"


func _clump(p: Vector2) -> float:
	return clampf(0.6 + _noise.get_noise_2d(p.x * 2.5 + 300.0, p.y * 2.5) * 1.2, 0.1, 1.3)


## Terrain normal at a point (from the height grid).
func _normal(p: Vector2) -> Vector3:
	var hl := _h(p + Vector2(-1, 0))
	var hr := _h(p + Vector2(1, 0))
	var hu := _h(p + Vector2(0, -1))
	var hd := _h(p + Vector2(0, 1))
	return Vector3(hl - hr, 2.0, hu - hd).normalized()


## Height in this node's space at a local X/Z.
func _h(p: Vector2) -> float:
	return height_at(p.x + global_position.x, p.y + global_position.z) - global_position.y


func _scatter_nature(rng: RandomNumberGenerator) -> void:
	var root := _root(nature_root)
	_colliders = StaticBody3D.new()
	_colliders.name = "Colliders"
	_colliders.add_to_group("no_spawn_ground")  # Spawn areas don't stand things on trunks.
	_add_generated(_colliders, root)
	_scenery = StaticBody3D.new()
	_scenery.name = "SceneryColliders"
	_scenery.collision_layer = SCENERY_LAYER
	_scenery.collision_mask = 0
	_scenery.add_to_group("no_spawn_ground")
	_add_generated(_scenery, root)
	var half := size * 0.5

	# Trees first (they claim the most room), then everything else.
	var candidates: Array[Vector2] = []
	var steps := int(size / tree_spacing)
	for ix in steps:
		for iz in steps:
			candidates.append(Vector2(-half + (ix + rng.randf()) * tree_spacing, -half + (iz + rng.randf()) * tree_spacing))
	for p in candidates:
		var roll := rng.randf()
		var zone := _zone(p)
		var slope := _normal(p).y
		var tree_chance := 0.0
		match zone:
			&"forest":
				tree_chance = forest_density * _clump(p) * (0.45 if _path_distance(p) < 5.5 else 1.0)
			&"cliff":
				tree_chance = 0.9 if slope > 0.45 else 0.0
			&"plain":
				tree_chance = 0.015
		if slope < 0.7 and zone != &"cliff":
			tree_chance = 0.0
		if roll < tree_chance:
			_place_tree(rng, p, zone == &"cliff")

	for p in candidates:
		var zone := _zone(p)
		if zone == &"":
			continue
		var slope := _normal(p).y
		var clump := _clump(p)
		var bush_chance := {&"forest": 0.22, &"plain": 0.07, &"clearing": 0.05, &"cliff": 0.25, &"cave_edge": 0.15}.get(zone, 0.0) as float
		if rng.randf() < bush_chance * clump and slope > 0.6:
			_place_bush(rng, p + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
		var rock_chance := {&"forest": 0.035, &"cliff": 0.08, &"cave": 0.12, &"cave_wall": 0.5, &"cave_edge": 0.25, &"cutting": 0.3, &"plain": 0.01, &"clearing": 0.02}.get(zone, 0.0) as float
		if rng.randf() < rock_chance:
			var q := p + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if zone == &"cave_wall":
				_place_cave_rock(rng, q)
			else:
				var big := zone == &"cliff" or zone == &"cave_edge" or (zone != &"cutting" and rng.randf() < 0.12)
				_place_rock(rng, q, big, "CaveRocks" if zone == &"cave" else "Rocks")
		if zone == &"cave" and rng.randf() < 0.03:
			_place_spire(rng, p)
		# Rubble along the cave walls and the cutting.
		if (zone == &"cave_wall" or zone == &"cutting") and rng.randf() < 0.45:
			_place_rubble(rng, p + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2)))
		# Glowing crystals and mushrooms (decoration only).
		var crystal_chance := {&"cave_wall": 0.28, &"cave": 0.04}.get(zone, 0.0) as float
		if rng.randf() < crystal_chance:
			_place_crystal(rng, p + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), zone == &"cave_wall")
		var plant_chance := {&"cave_wall": 0.3, &"cave": 0.08}.get(zone, 0.0) as float
		if rng.randf() < plant_chance:
			_place_glow_plant(rng, p + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2)))
		if zone == &"forest" and rng.randf() < 0.012 and slope > 0.85:
			_place_log(rng, p)

	_scatter_ground_cover(rng)


func _place_tree(rng: RandomNumberGenerator, p: Vector2, on_cliff: bool) -> void:
	var model := NATURE % (_pick(rng, TREES_BARE) if rng.randf() < 0.05 else _pick(rng, TREES))
	var s := rng.randf_range(tree_scale.x, tree_scale.y) * (1.25 if on_cliff else 1.0)
	if not _claim(p, _radius(model, s, TREE_FOOTPRINT)):
		return
	# Deeper on slopes so no root floats on the downhill side.
	var sink := -0.15 - (1.0 - _normal(p).y) * 2.0
	_queue("Trees", 40.0, model, _xform(p, rng.randf() * TAU, s, sink, 0.0), true)
	# Trunk collider (tall, so nothing spawns on top of it).
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.22 * s
	trunk.height = 4.0 * s
	_add_shape(_colliders, trunk, Transform3D(Basis.IDENTITY, Vector3(p.x, _h(p) + trunk.height * 0.5, p.y)))


func _place_bush(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := NATURE % _pick(rng, BUSHES)
	var s := rng.randf_range(0.9, 1.5)
	var radius := _radius(model, s)
	if _path_distance(p) < radius + 1.0 or not _claim(p, radius):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.05, 0.6)
	_queue("Bushes", 40.0, model, xform, true, 90.0)
	var body := CylinderShape3D.new()
	body.radius = radius * 0.8
	body.height = 1.2 * s
	_add_shape(_scenery, body, Transform3D(Basis.IDENTITY, xform.origin + Vector3.UP * body.height * 0.5))


func _place_rock(rng: RandomNumberGenerator, p: Vector2, big: bool, group: String = "Rocks") -> void:
	var model := NATURE % _pick(rng, ROCKS_BIG if big else ROCKS_SMALL)
	var s := rng.randf_range(0.8, 1.3) if big else rng.randf_range(0.7, 1.4)
	var radius := _radius(model, s)
	var ceiling := _cave_height(p)
	if ceiling > 0.0 and KitPiece.model_aabb(model).size.y * s > ceiling - 0.4:
		return
	if _path_distance(p) < radius + 1.0 or not _claim(p, radius):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.15 * s, 1.0)
	_queue(group, 40.0, model, xform, true)
	var box := KitPiece.model_aabb(model)
	_add_shape_box(_colliders if box.size.length() * s > 1.6 else _scenery, xform, box, 0.8)


## Rocks along the cave's inside walls, half sunk into the floor and wall,
## always fitting under the ceiling.
func _place_cave_rock(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := NATURE % _pick(rng, ROCKS_WALL)
	var s := rng.randf_range(0.7, 1.2)
	var box := KitPiece.model_aabb(model)
	if box.size.y * s > _cave_height(p) - 0.4 or not _claim(p, _radius(model, s) * 0.8):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.2 * s, 1.0)
	_queue("CaveRocks", 40.0, model, xform, true)
	_add_shape_box(_colliders, xform, box, 0.8)


## Small KayKit rocks and stone chunks along the cave walls and the cutting.
func _place_rubble(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := RESOURCE % _pick(rng, ["Stone_Chunks_Small", "Stone_Chunks_Large"]) if rng.randf() < 0.5 \
		else NATURE % _pick(rng, ["Rock_2_A", "Rock_2_B", "Rock_1_A", "Rock_1_B"])
	var s := rng.randf_range(0.6, 1.1)
	var box := KitPiece.model_aabb(model)
	var ceiling := _cave_height(p)
	if (ceiling > 0.0 and box.size.y * s > ceiling - 0.4) or not _claim(p, _radius(model, s) * 0.8):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.05 * s, 1.0)
	_queue("CaveRocks" if p.y < cave_mouth.y else "Rocks", 40.0, model, xform, true)
	_add_shape_box(_scenery, xform, box, 0.8)


## A cluster of glowing crystals, leaning out of the wall into the cave.
func _place_crystal(rng: RandomNumberGenerator, p: Vector2, at_wall: bool) -> void:
	var s := rng.randf_range(0.7, 1.4)
	if _cave_height(p) < 1.3 * s + 0.3 or not _claim(p, 0.4 * s):
		return
	var tint := "cyan" if rng.randf() < 0.6 else "violet"
	var lean := Basis.IDENTITY
	if at_wall:
		var inward := _cave_inward(p)
		var axis := Vector3(inward.y, 0.0, -inward.x)  # Tips the top toward the inside.
		lean = Basis(axis.normalized(), deg_to_rad(rng.randf_range(15.0, 35.0)))
	var turn := (lean * Basis(Vector3.UP, rng.randf() * TAU)).scaled(Vector3.ONE * s)
	var xform := Transform3D(turn, Vector3(p.x, _h(p) - 0.05 * s, p.y))
	_queue("Crystals", 40.0, "crystal_%s_%d" % [tint, rng.randi() % 3], xform, false, 70.0)
	var blocker := CylinderShape3D.new()
	blocker.radius = 0.35 * s
	blocker.height = 1.0 * s
	_add_shape(_scenery, blocker, Transform3D(Basis.IDENTITY, xform.origin + Vector3.UP * blocker.height * 0.5))


## A cluster of glowing mushrooms on the cave floor (decoration only).
func _place_glow_plant(rng: RandomNumberGenerator, p: Vector2) -> void:
	var s := rng.randf_range(0.8, 1.5)
	if _cave_height(p) < 0.6 * s + 0.3 or not _claim(p, 0.25 * s):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.02, 0.6)
	_queue("GlowPlants", 40.0, "mushrooms_%d" % (rng.randi() % 2), xform, false, 60.0)
	var blocker := CylinderShape3D.new()
	blocker.radius = 0.22 * s
	blocker.height = 0.3 * s
	_add_shape(_scenery, blocker, Transform3D(Basis.IDENTITY, xform.origin + Vector3.UP * blocker.height * 0.5))


## Tall rock spire in the cave, only where the ceiling is high enough.
func _place_spire(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := NATURE % _pick(rng, ROCKS_SPIRE)
	var s := rng.randf_range(0.7, 1.1)
	var box := KitPiece.model_aabb(model)
	if _cave_height(p) < box.size.y * s + 1.0 or not _claim(p, _radius(model, s)):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.2 * s, 0.0)
	_queue("CaveRocks", 40.0, model, xform, true)
	_add_shape_box(_colliders, xform, box, 0.8)


func _place_log(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := RESOURCE % _pick(rng, LOGS)
	var s := rng.randf_range(2.0, 2.6)
	var box := KitPiece.model_aabb(model)
	# A log is long: it claims a circle of half its length.
	if _path_distance(p) < box.size.z * s * 0.5 + 1.0 or not _claim(p, box.size.z * s * 0.5):
		return
	# The log model is centred on its origin: lift it so it lies slightly sunk,
	# along the slope.
	var xform := _xform(p, rng.randf() * TAU, s, 0.0, 1.0)
	xform.origin += xform.basis.y.normalized() * 0.2 * s
	_queue("Logs", 40.0, model, xform, true)
	_add_shape_box(_colliders, xform, box, 0.85)


## A box collider matching a model's bounds (shrunk a little), placed like it.
func _add_shape_box(body: StaticBody3D, xform: Transform3D, box: AABB, shrink: float) -> void:
	var shape := BoxShape3D.new()
	var s := xform.basis.get_scale()
	shape.size = box.size * s * shrink
	var unscaled := Transform3D(xform.basis.orthonormalized(), xform.origin)
	_add_shape(body, shape, unscaled * Transform3D(Basis.IDENTITY, box.get_center() * s))


static func _add_shape(body: StaticBody3D, shape: Shape3D, xform: Transform3D) -> void:
	var owner_id := body.create_shape_owner(body)
	body.shape_owner_add_shape(owner_id, shape)
	body.shape_owner_set_transform(owner_id, xform)


## Grass tufts, meadow flowers and reeds (no collision, short draw distance),
## never inside a rock, log, bush or trunk.
func _scatter_ground_cover(rng: RandomNumberGenerator) -> void:
	var half := size * 0.5
	var spacing := 1.4
	var steps := int(size / spacing)
	for ix in steps:
		for iz in steps:
			var p := Vector2(-half + (ix + rng.randf()) * spacing, -half + (iz + rng.randf()) * spacing)
			var roll := rng.randf()
			var zone := _zone(p)
			var chance := {&"plain": 0.8, &"clearing": 0.55, &"forest": 0.3, &"cave_edge": 0.3, &"path": 0.04}.get(zone, 0.0) as float
			if roll < chance * grass_density and _normal(p).y > 0.75 and _is_free(p, 0.15):
				_queue("Grass", 20.0, NATURE % _pick(rng, GRASS), _xform(p, rng.randf() * TAU, rng.randf_range(0.9, 1.6), -0.03, 0.5), false, 45.0)
			if zone == &"plain" and rng.randf() < 0.3:
				var q := p + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
				if _is_free(q, 0.1):
					_queue("Flowers", 20.0, "flower", _xform(q, rng.randf() * TAU, rng.randf_range(0.8, 1.3), -0.02, 0.5), false, 45.0,
						FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()])

	# Reeds in the shallows around the lake and along the stream banks.
	for i in 900:
		var angle := rng.randf() * TAU
		var r := lake_radius + rng.randf_range(-3.5, 1.5)
		var p := lake_center + Vector2(cos(angle), sin(angle)) * r
		if _project(p, stream).x < stream_half_width + 0.5 or not _is_free(p, 0.15):
			continue
		if rng.randf() < 0.6:
			_queue("Reeds", 40.0, NATURE % _pick(rng, REEDS), _xform(p, rng.randf() * TAU, rng.randf_range(1.6, 2.4), -0.05, 0.0), false, 70.0)
	var total := _line_length(stream)
	var along := 0.0
	while along < total:
		along += rng.randf_range(0.6, 1.6)
		var at := _point_along(stream, along)
		if at.distance_to(lake_center) < lake_radius + 1.0:
			continue
		var ahead := _point_along(stream, minf(along + 0.5, total)) - _point_along(stream, maxf(along - 0.5, 0.0))
		var side := Vector2(-ahead.y, ahead.x).normalized() * (stream_half_width + rng.randf_range(0.2, 1.2)) * (1.0 if rng.randf() < 0.5 else -1.0)
		if _is_free(at + side, 0.15):
			_queue("Reeds", 40.0, NATURE % _pick(rng, REEDS), _xform(at + side, rng.randf() * TAU, rng.randf_range(1.4, 2.1), -0.05, 0.0), false, 70.0)


## Placement on the ground: turned `yaw`, uniform scale `s`, lowered by `sink`,
## leaning with the slope by `follow` (0 = upright, 1 = along the ground).
func _xform(p: Vector2, yaw: float, s: float, sink: float, follow: float) -> Transform3D:
	var lean := Quaternion.IDENTITY
	if follow > 0.0:
		lean = Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, _normal(p)), follow)
	var turn := (Basis(lean) * Basis(Vector3.UP, yaw)).scaled(Vector3.ONE * s)
	return Transform3D(turn, Vector3(p.x, _h(p) + sink, p.y))


static func _pick(rng: RandomNumberGenerator, names: Array) -> String:
	return names[rng.randi() % names.size()]


## Footprint radius of a model at scale `s` (half its widest side) x factor.
static func _radius(path: String, s: float, factor: float = 1.0) -> float:
	var box := KitPiece.model_aabb(path)
	return maxf(box.size.x, box.size.z) * 0.5 * s * factor


## True if a circle at `p` with `radius` overlaps nothing placed so far.
func _is_free(p: Vector2, radius: float) -> bool:
	var at := Vector2i(floori(p.x / TAKEN_CELL), floori(p.y / TAKEN_CELL))
	var reach := ceili((radius + TAKEN_MAX_RADIUS) / TAKEN_CELL)
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for other: Vector3 in _taken.get(at + Vector2i(dx, dz), []):
				if p.distance_to(Vector2(other.x, other.y)) < radius + other.z:
					return false
	return true


## Takes the spot if it is free; returns whether it was.
func _claim(p: Vector2, radius: float) -> bool:
	if not _is_free(p, radius):
		return false
	var at := Vector2i(floori(p.x / TAKEN_CELL), floori(p.y / TAKEN_CELL))
	if not _taken.has(at):
		_taken[at] = []
	(_taken[at] as Array).append(Vector3(p.x, p.y, minf(radius, TAKEN_MAX_RADIUS)))
	return true


# --- MultiMesh batching -------------------------------------------------------

## Collects one instance. Batches are per group, chunk and model; each chunk
## becomes its own MultiMeshInstance3D (culled and distance-limited alone).
func _queue(group: String, chunk: float, path: String, xform: Transform3D, shadows: bool,
		draw_distance: float = 150.0, color: Color = Color.WHITE) -> void:
	var cx := floori(xform.origin.x / chunk)
	var cz := floori(xform.origin.z / chunk)
	var key := "%s|%s|%d|%d" % [group, path, cx, cz]
	if not _batches.has(key):
		_batches[key] = {
			"group": group, "path": path, "shadows": shadows, "distance": draw_distance,
			"centre": Vector3((cx + 0.5) * chunk, 0.0, (cz + 0.5) * chunk), "xforms": [], "colors": [],
		}
	(_batches[key]["xforms"] as Array).append(xform)
	(_batches[key]["colors"] as Array).append(color)


func _flush_batches() -> void:
	var root := _root(nature_root)
	_custom_meshes["flower"] = _flower_mesh()
	for tint in ["cyan", "violet"]:
		for variant in 3:
			_custom_meshes["crystal_%s_%d" % [tint, variant]] = _crystal_mesh(variant, tint)
	for variant in 2:
		_custom_meshes["mushrooms_%d" % variant] = _mushroom_mesh(variant)
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var parent := _container(root, batch["group"])
		var centre: Vector3 = batch["centre"]
		var xforms: Array = batch["xforms"]
		var path: String = batch["path"]
		var parts: Array = [{"mesh": _custom_meshes[path], "xform": Transform3D.IDENTITY}] if _custom_meshes.has(path) else KitPiece.model_parts(path)
		for part in parts:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = batch["path"] == "flower"
			multimesh.mesh = part["mesh"]
			multimesh.instance_count = xforms.size()
			var part_xform: Transform3D = part["xform"]
			for i in xforms.size():
				var xform: Transform3D = xforms[i]
				xform.origin -= centre
				multimesh.set_instance_transform(i, xform * part_xform)
				if multimesh.use_colors:
					multimesh.set_instance_color(i, batch["colors"][i])
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			# Placed at the chunk centre so the draw distance is measured from there.
			instance.position = centre
			instance.visibility_range_end = batch["distance"]
			if batch["group"] in CAVE_GROUPS:
				instance.layers = CAVE_RENDER_LAYER  # No sunlight inside the cave.
			if not batch["shadows"]:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(instance)
	_batches.clear()


## Small meadow flower: a green stem and a flat petal head that takes the
## instance colour (flat shaded, like the KayKit plants).
func _flower_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var stem := SurfaceTool.new()
	stem.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI * 0.5]:
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.008
		for v in [-side, side, side + Vector3.UP * 0.26, -side, side + Vector3.UP * 0.26, -side + Vector3.UP * 0.26]:
			stem.set_normal(Vector3(sin(angle), 0.0, -cos(angle)))
			stem.add_vertex(v)
	stem.commit(mesh)
	var stem_material := StandardMaterial3D.new()
	stem_material.albedo_color = Color(0.33, 0.6, 0.3)
	stem_material.roughness = 1.0
	stem_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, stem_material)

	var head := SurfaceTool.new()
	head.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0.0, 0.27, 0.0)
	var petals := 6
	for i in petals:
		var a0 := TAU * i / petals
		var a1 := TAU * (i + 0.5) / petals
		var tip := centre + Vector3(cos(a1) * 0.07, 0.025, sin(a1) * 0.07)
		var left := centre + Vector3(cos(a0) * 0.03, 0.0, sin(a0) * 0.03)
		var right := centre + Vector3(cos(TAU * (i + 1) / petals) * 0.03, 0.0, sin(TAU * (i + 1) / petals) * 0.03)
		for v in [centre, left, tip, centre, tip, right]:
			head.set_color(Color.WHITE)
			head.set_normal(Vector3.UP)
			head.add_vertex(v)
	head.commit(mesh)
	var head_material := StandardMaterial3D.new()
	head_material.vertex_color_use_as_albedo = true
	head_material.roughness = 0.9
	head_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, head_material)
	return mesh


## Crystal cluster: a few six-sided crystals with pointed tips, flat shaded
## like the KayKit models, glowing softly (emission).
func _crystal_mesh(variant: int, tint: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3 + variant:
		var radius := rng.randf_range(0.07, 0.13) * (1.5 if i == 0 else 1.0)
		var height := rng.randf_range(0.45, 0.8) * (1.4 if i == 0 else 1.0)
		var base := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-0.18, 0.18), 0.0, rng.randf_range(-0.18, 0.18))
		base.y = -0.1
		var tilt := Basis.IDENTITY
		var axis := Vector3(base.z, 0.0, -base.x)
		if i > 0 and axis.length() > 0.01:
			tilt = Basis(axis.normalized(), -deg_to_rad(rng.randf_range(15.0, 40.0)))
		var bottom: Array[Vector3] = []
		var top: Array[Vector3] = []
		var start := rng.randf() * TAU
		for k in 6:
			var angle := start + TAU * k / 6.0
			var around := Vector3(cos(angle), 0.0, sin(angle)) * radius
			bottom.append(base + tilt * around)
			top.append(base + tilt * (around * 0.85 + Vector3.UP * height))
		var tip := base + tilt * (Vector3.UP * (height + radius * 1.8))
		for k in 6:
			var k2 := (k + 1) % 6
			_st_tri(st, bottom[k], top[k], bottom[k2])
			_st_tri(st, top[k], top[k2], bottom[k2])
			_st_tri(st, top[k], tip, top[k2])
	st.generate_normals()
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	var glow := Color(0.3, 0.8, 1.0) if tint == "cyan" else Color(0.62, 0.38, 1.0)
	material.albedo_color = Color(0.5, 0.9, 1.0) if tint == "cyan" else Color(0.76, 0.58, 1.0)
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = 1.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


## Cluster of three small mushrooms: pale stems, glowing caps.
func _mushroom_mesh(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 950 + variant
	var stems := SurfaceTool.new()
	stems.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps := SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var at := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
		var stem_h := rng.randf_range(0.1, 0.22) * (1.3 if i == 0 else 1.0)
		var stem_r := rng.randf_range(0.015, 0.03)
		var cap_r := stem_r * rng.randf_range(2.6, 3.4)
		for k in 6:
			var a0 := TAU * k / 6.0
			var a1 := TAU * (k + 1) / 6.0
			var s0 := Vector3(cos(a0), 0.0, sin(a0)) * stem_r
			var s1 := Vector3(cos(a1), 0.0, sin(a1)) * stem_r
			_st_tri(stems, at + s0, at + s0 + Vector3.UP * stem_h, at + s1)
			_st_tri(stems, at + s0 + Vector3.UP * stem_h, at + s1 + Vector3.UP * stem_h, at + s1)
		var top := at + Vector3.UP * (stem_h + cap_r * 0.7)
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			var rim0 := at + Vector3(cos(a0) * cap_r, stem_h, sin(a0) * cap_r)
			var rim1 := at + Vector3(cos(a1) * cap_r, stem_h, sin(a1) * cap_r)
			var mid0 := at + Vector3(cos(a0) * cap_r * 0.7, stem_h + cap_r * 0.45, sin(a0) * cap_r * 0.7)
			var mid1 := at + Vector3(cos(a1) * cap_r * 0.7, stem_h + cap_r * 0.45, sin(a1) * cap_r * 0.7)
			var under := at + Vector3.UP * (stem_h - cap_r * 0.1)
			_st_tri(caps, rim0, mid0, rim1)
			_st_tri(caps, mid0, mid1, rim1)
			_st_tri(caps, mid0, top, mid1)
			_st_tri(caps, rim0, rim1, under)
	stems.generate_normals()
	caps.generate_normals()
	var mesh := ArrayMesh.new()
	stems.commit(mesh)
	caps.commit(mesh)
	var stem_material := StandardMaterial3D.new()
	stem_material.albedo_color = Color(0.86, 0.88, 0.8)
	stem_material.roughness = 0.9
	stem_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, stem_material)
	var cap_material := StandardMaterial3D.new()
	var glow := Color(0.25, 0.9, 0.62) if variant == 0 else Color(0.35, 0.6, 1.0)
	cap_material.albedo_color = Color(0.45, 1.0, 0.8) if variant == 0 else Color(0.55, 0.78, 1.0)
	cap_material.roughness = 0.6
	cap_material.emission_enabled = true
	cap_material.emission = glow
	cap_material.emission_energy_multiplier = 1.4
	cap_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, cap_material)
	return mesh


## One triangle (normals are generated afterwards; the materials draw both
## sides, so the winding doesn't matter).
static func _st_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


# --- Light shafts -----------------------------------------------------------

## Soft beams slanting down from the sun into the forest (additive, no light).
func _build_light_shafts(rng: RandomNumberGenerator) -> void:
	if light_shafts <= 0:
		return
	var root := _root(shafts_root)
	var sun_node := get_node_or_null(sun) as Node3D
	var toward_sun := sun_node.global_basis.z.normalized() if sun_node else Vector3(0.4, 0.8, 0.4).normalized()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 0.94, 0.75, 0.07)
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 3.0
	material.distance_fade_max_distance = 12.0
	var beam := CylinderMesh.new()
	beam.top_radius = 1.4
	beam.bottom_radius = 2.4
	beam.height = 24.0
	beam.cap_top = false
	beam.cap_bottom = false
	beam.radial_segments = 12
	beam.material = material

	var y_axis := toward_sun
	var x_axis := y_axis.cross(Vector3.FORWARD).normalized()
	if x_axis.length() < 0.1:
		x_axis = Vector3.RIGHT
	var z_axis := x_axis.cross(y_axis).normalized()
	var placed := 0
	var tries := 0
	while placed < light_shafts and tries < light_shafts * 40:
		tries += 1
		var p := Vector2(rng.randf_range(-size * 0.4, size * 0.4), rng.randf_range(-size * 0.4, size * 0.4))
		var zone := _zone(p)
		if zone != &"forest" and zone != &"clearing":
			continue
		var bottom := Vector3(p.x, _h(p), p.y)
		var shaft := MeshInstance3D.new()
		shaft.name = "Shaft%d" % placed
		shaft.mesh = beam
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.transform = Transform3D(Basis(x_axis, y_axis, z_axis), bottom + y_axis * beam.height * 0.5)
		shaft.visibility_range_end = 90.0
		_add_generated(shaft, root)
		placed += 1


# --- Helpers ----------------------------------------------------------------

func _root(path: NodePath) -> Node3D:
	var node := get_node_or_null(path) as Node3D
	return node if node else self


func _container(root: Node3D, group: String) -> Node3D:
	var key := "%s/%s" % [root.get_path(), group]
	if _containers.has(key):
		return _containers[key]
	var node := Node3D.new()
	node.name = group
	_add_generated(node, root)
	_containers[key] = node
	return node


func _add_generated(node: Node, parent: Node) -> void:
	parent.add_child(node)
	_generated.append(node)
