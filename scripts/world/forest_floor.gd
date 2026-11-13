@tool
class_name ForestFloor
extends Node3D
## Builds dungeon floor 1, a forest inside the magic dungeon, from code (like
## the guild's Outside): rebuilt live in the editor when a setting changes,
## generated nodes aren't saved, same seed = same floor.
##
## - Terrain: a low-poly heightmap (flat-shaded faces, one KayKit-palette
##   colour per face: grass, dirt paths, sandy shores, rock) with collision.
##   Gentle hills, stepped rocky cliffs along an irregular outline (bays and
##   outcrops, height varying along the edge), a lake with shallow edges, a
##   stream valley, dirt paths, and a hole cut for each stair portal
##   (DungeonEntrance) so its pit shows.
## - Cave: cut into a rocky spur of the outer cliff wall. Its mouth is where
##   the cave's vault breaks out of the steep cliff face, so the opening is a
##   rough, irregular hole in the rock (no cutting, no neat arch); inside,
##   passages open into wider chambers. Where the rock covers the cave, the
##   ground mesh is cut away and the cave brings its own floor, walls and
##   ceiling, plus an outer roof that follows the cliff's own heights, so the
##   cliff has no seams. Outline, ceiling and floor are roughened with noise; KayKit rocks,
##   rubble, glowing crystals and glowing mushrooms line the walls (a few soft
##   lights, one per chamber). The inside is on render layer 2, which the sun
##   skips; daylight seems to spill a few metres in from the mouth. The
##   `cave_darkness` area fades to a dark ambient light inside.
## - Water: the lake, a pool at the edge cliff foot and the stream from the pool
##   into the lake (one strip overlapping both, streaks moving with the flow);
##   collision on layer 5 only (spawn areas avoid
##   it; the player wades through).
## - Rock skin: many smaller KayKit rocks (mostly small and medium, a few
##   large), turned at random, overlapping and half buried, densely cover the
##   edge cliffs, the cave's spur and its walls and ceiling (rubble at the cliff
##   foot; head room kept in the cave), and steep slopes get some too.
## - Nature: every KayKit tree model (uniform scale, 3-5 m trunks; the slim ones
##   40-70 m tall, the stout ones smaller), slightly tinted, some with rocks,
##   bushes or a log at the base; bushes, rocks, logs, grass and reeds, plus small flowers, as MultiMeshes in chunks
##   (each chunk drawn only up to its own distance). The ground mesh is chunked
##   too, so what's behind the camera is culled. Nothing overlaps: every piece claims its footprint. Rocks,
##   logs and bushes lean with the slope. Trees, big rocks and logs collide
##   (layer 1); bushes and small rocks only block spawn areas (layer 6).
##   Nothing grows on or against the edge cliffs and the cave's cliff spur
##   (`edge_margin` keeps a clear strip in front of them).
## - Snapping: every direct child of the `snap_roots` (portals, spawn points,
##   spawn areas) is moved onto the ground. Optional meta "snap_offset"
##   (float) lifts it; meta "no_snap" skips it.
##
## Coordinates: the floor is centred on this node; +Z is south.

const NATURE := "res://KayKit/Assets4/gltf/%s_Color1.gltf"
const RESOURCE := "res://KayKit/Assets3/gltf/%s.gltf"
const TERRAIN_MATERIAL := "res://materials/world/floor1_terrain.tres"
const WATER_MATERIAL := "res://materials/world/water.tres"
## The pool at the cliff foot where the stream starts (the waterfall scene,
## scenes/world/waterfall.tscn, is placed above it by hand).
const POOL_RADIUS := 7.0
## Columns across the stream's water strip (about 1 m wide each).
const STREAM_COLUMNS := 8
const WATER_LAYER := 16  # Physics layer 5.
const SCENERY_LAYER := 32  # Physics layer 6: only spawn areas look at it.
## Render layer 2: the cave's inside and everything in it. The sun's cull mask
## leaves this layer out, so only the cave's own lights and glow light it.
const CAVE_RENDER_LAYER := 2
## MultiMesh groups that live inside the cave (drawn on CAVE_RENDER_LAYER).
const CAVE_GROUPS := ["CaveRocks", "CaveSkin", "Crystals", "GlowPlants"]
## How far into the cave daylight seems to spill (metres from the mouth).
const CAVE_SPILL_DEPTH := 20.0
## How much bigger the cave's rock features are than the original small cave:
## the wall, ceiling and floor noise is this much wider and deeper.
const CAVE_SCALE := 2.5
## The ground mesh is split into square chunks of this many cells, so the
## parts behind the camera are culled.
const GROUND_CHUNK_CELLS := 25

## Every KayKit tree: [trunk diameter at scale 1, how often it's picked].
## The scale (always uniform) is picked so the tree is `tree_height` tall with
## a trunk `trunk_width` wide. The round, stout models can't be that tall
## without a far too thick trunk, so the trunk wins for them: they grow as
## smaller trees (about 17-36 m) between the giants.
const TREE_MODELS := {
	"Tree_1_A": [0.85, 0.6], "Tree_1_B": [0.75, 0.6], "Tree_1_C": [1.1, 0.6],
	"Tree_2_A": [0.33, 1.0], "Tree_2_B": [0.38, 1.0], "Tree_2_C": [0.55, 1.0], "Tree_2_D": [0.55, 1.0], "Tree_2_E": [0.58, 1.0],
	"Tree_3_A": [0.85, 0.6], "Tree_3_B": [0.8, 0.6], "Tree_3_C": [1.1, 0.6],
	"Tree_4_A": [0.27, 1.0], "Tree_4_B": [0.45, 1.0], "Tree_4_C": [0.5, 1.0],
	"Tree_Bare_1_A": [0.9, 0.12], "Tree_Bare_1_B": [0.8, 0.12], "Tree_Bare_1_C": [1.1, 0.12],
	"Tree_Bare_2_A": [0.33, 0.12], "Tree_Bare_2_B": [0.43, 0.12], "Tree_Bare_2_C": [0.43, 0.12],
}
## Some trees get a few rocks, bushes or a log around their base.
const TREE_BASE_CHANCE := 0.35
## Rock skin on the cliff and cave walls: many smaller KayKit rocks, mostly
## small and medium, a few large: [models, scale min, scale max] per tier.
## (Large ones use the lighter big models; the 850-vertex ones are left out.)
const CLIFF_TIERS := {
	"large": [["Rock_2_E", "Rock_2_F", "Rock_2_G", "Rock_2_H",
		"Rock_3_M", "Rock_3_N", "Rock_3_O", "Rock_3_P", "Rock_3_Q", "Rock_3_R"], 1.0, 2.0],
	"medium": [["Rock_1_G", "Rock_1_H", "Rock_1_I", "Rock_2_D", "Rock_3_G", "Rock_3_H", "Rock_3_I", "Rock_3_J",
		"Rock_3_K", "Rock_3_L"], 1.0, 2.2],
	"small": [["Rock_1_D", "Rock_1_E", "Rock_1_F", "Rock_2_C", "Rock_3_A", "Rock_3_B", "Rock_3_C", "Rock_3_D",
		"Rock_3_E", "Rock_3_F"], 0.9, 2.0],
	"rubble": [["Rock_1_A", "Rock_1_B", "Rock_1_C", "Rock_2_A", "Rock_2_B"], 1.0, 2.5],
}
## Share of `cliff_rock_density` that goes into the main layer (medium, a few
## large; drawn far); the rest is the fine layer (small rocks and rubble).
const CLIFF_MAIN_SHARE := 0.31
## Head room kept under rocks hanging from the cave ceiling (metres above the
## floor), and more along the entrance walkway.
const CAVE_HEADROOM := 2.8
const CAVE_WALKWAY_HEADROOM := 3.5
## Where the cave ceiling is lower than this, it's the foot of a wall: only
## thin rocks there (sticking out at most CAVE_WALL_FOOT_REACH), so ore
## veins, crystals and mushrooms at the walls stay visible.
const CAVE_WALL_FOOT := 3.5
const CAVE_WALL_FOOT_REACH := 0.5
## How far in the floor's outline is pushed at most (bays and outcrops).
const EDGE_INSET := 40.0
## Bushes, rocks and the like are placed on this grid (trees use tree_spacing).
const UNDERGROWTH_SPACING := 4.0
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
## Room a tree claims around its trunk (metres past the bark), and the gap
## kept to other trunks: crowns may overlap, trunks, rocks, logs and bushes
## never do.
const TREE_ROOM := 0.3
const TREE_GAP := 6.7
## Rock above the cave's vault needed for it to count as covered (inside the
## mountain); where the cliff is thinner than this, the cave is open: its mouth.
const CAVE_ROOF_MIN := 1.0
## How steep the cliff face is around the cave mouth: the spur's rock side is
## only this wide there (metres), so the mouth is a hole in a rock face.
const MOUTH_SLOPE := 5.0
## Half width of the walkway through the cave's entrance kept free of rocks.
const ENTRANCE_WALKWAY := 4.0
const TAKEN_CELL := 8.0
const TAKEN_MAX_RADIUS := 8.0

@export var layout_seed: int = 11

@export_group("Terrain")
## Width and depth in metres (square, centred on this node).
@export var size: float = 500.0
## Distance between terrain vertices.
@export var cell: float = 2.0
@export var hill_height: float = 12.0
@export var hill_frequency: float = 0.005
## Width of the rising rim at the floor's edge, and how high the cliffs get
## on average (the height varies along the edge).
@export var edge_band: float = 30.0
@export var cliff_height: float = 40.0
## Clear strip in front of the edge cliffs and the cave's cliff spur: no
## trees, rocks, bushes or logs on the cliffs or within this many metres of them.
@export var edge_margin: float = 10.0

@export_group("Places")
## Stair portals (DungeonEntrance). The terrain is flattened around them and
## a hole is cut for their footprint.
@export var portals: Array[NodePath] = [NodePath("../Portals/ArrivalStairs"), NodePath("../Portals/ExitStairs")]
## The first portal's clearing stays free of trees.
@export var clearing_radius: float = 40.0
@export var lake_center: Vector2 = Vector2(-137.5, 62.5)
@export var lake_radius: float = 40.0
@export var lake_depth: float = 3.5
@export var water_level: float = 0.0
## Stream into the lake (points from its lake end): it starts at a waterfall
## where it reaches the edge cliffs (its far end runs into them) and flows
## down to the lake.
@export var stream: PackedVector2Array = PackedVector2Array([Vector2(-130, 95), Vector2(-112.5, 125), Vector2(-117.5, 157.5), Vector2(-100, 185), Vector2(-110, 235)])
@export var stream_half_width: float = 3.0
## How much the water level rises per metre up the stream, from the lake
## shore to the waterfall pool.
@export var stream_drop: float = 0.02
@export var plain_center: Vector2 = Vector2(125, 87.5)
@export var plain_radius: float = 75.0
## Dirt paths (each a line of points).
@export var paths: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 182), Vector2(15, 145), Vector2(55, 115), Vector2(95, 95)]),
	PackedVector2Array([Vector2(15, 145), Vector2(-25, 120), Vector2(-65, 85), Vector2(-92.5, 65)]),
	PackedVector2Array([Vector2(15, 145), Vector2(25, 75), Vector2(35, 12.5), Vector2(5, -55), Vector2(-35, -110), Vector2(-85, -155), Vector2(-140, -172)]),
	PackedVector2Array([Vector2(35, 12.5), Vector2(75, -50), Vector2(100, -100), Vector2(100, -124)]),
]

@export_group("Cave")
## The rocky spur of the outer cliff wall the cave is cut into: this area
## (x, z, width, depth) rises `cave_cliff_height` above the ground, with steep
## rock sides `cave_cliff_slope` metres wide.
@export var cave_cliff: Rect2 = Rect2(12.5, -250, 212.5, 112.5)
@export var cave_cliff_height: float = 60.0
@export var cave_cliff_slope: float = 20.0
## Chambers and passages, each [x1, z1, x2, z2, radius, ceiling height]:
## a capsule from point 1 to point 2 (the same point twice = a round chamber).
## The outline is roughened with noise, so these are only the rough shape.
@export var cave_shapes: Array[PackedFloat32Array] = [
	PackedFloat32Array([100, -118, 100, -156, 7.0, 9.0]),        # Entrance tunnel (first shape: kept clear to walk in).
	PackedFloat32Array([100, -170, 100, -170, 16.0, 14.0]),      # Entry hall.
	PackedFloat32Array([100, -170, 117.5, -192.5, 7.0, 9.0]),    # Passage to the main chamber.
	PackedFloat32Array([125, -207.5, 125, -207.5, 30.0, 22.0]),  # Main chamber.
	PackedFloat32Array([125, -207.5, 170, -195, 7.0, 9.0]),      # Passage east.
	PackedFloat32Array([177.5, -192.5, 177.5, -192.5, 20.0, 16.0]),  # East chamber.
	PackedFloat32Array([125, -207.5, 75, -200, 6.5, 8.5]),       # Passage west.
	PackedFloat32Array([65, -197.5, 65, -197.5, 15.0, 13.0]),    # West alcove.
]
## Roughly where the cave's mouth is in the cliff face (the opening itself is
## wherever the vault breaks out of the rock). Around this X the cliff face is
## steep; the cave floor is level with the ground just in front of it, and
## daylight seems to spill in from here.
@export var cave_mouth: Vector2 = Vector2(100, -134)
## How lumpy the rock is: walls wandering in and out, bumps and hanging
## rock on the ceiling, an uneven floor (0 = smooth).
@export_range(0.0, 2.0) var cave_roughness: float = 1.0

@export_group("Nature")
@export_range(0.0, 1.0) var forest_density: float = 0.6
@export_range(0.0, 1.0) var grass_density: float = 1.0
## Grid cell for tree candidates (smaller = more trees).
@export var tree_spacing: float = 6.0
## Forest trees are this tall (metres, min / max)...
@export var tree_height: Vector2 = Vector2(40, 70)
## ...with a trunk this wide (scaling is always uniform, so both decide the scale).
@export var trunk_width: Vector2 = Vector2(3, 5)

@export_group("Cliff Rocks")
## Rocks per square metre of cliff wall (edge cliffs and the cave's spur),
## counted along the wall's own surface, so steep faces get as many as gentle
## ones. About a third go into the main layer (medium and a few large, drawn
## far), the rest into the fine layer (small rocks and rubble, drawn near).
@export_range(0.05, 5.0, 0.01) var cliff_rock_density: float = 1.1
## Size of each rock (its longest side, metres): min / max.
@export var cliff_rock_size: Vector2 = Vector2(0.2, 10.5)
## How much of each rock is buried in the wall (0 = just touching it, 0.95 =
## almost hidden). More sinking = flatter, more overlapping rock.
@export_range(0.0, 0.95, 0.01) var cliff_rock_sink: float = 0.78

@export_group("Cave Rocks")
## Rocks per square metre of the cave's walls and ceiling (along the surface).
@export_range(0.05, 5.0, 0.01) var cave_rock_density: float = 0.9
## Size of each rock (its longest side, metres): min / max. Rocks at the foot
## of the walls are kept thin whatever this says.
@export var cave_rock_size: Vector2 = Vector2(0.3, 10.5)
## How much of each rock is buried in the wall or ceiling (0 = just touching,
## 0.95 = almost hidden).
@export_range(0.0, 0.95, 0.01) var cave_rock_sink: float = 0.78

@export_group("Scene")
@export var nature_root: NodePath = NodePath("../Nature")
@export var water_root: NodePath = NodePath("../Water")
## Area3D (an AmbienceZone) that gets the cave's shapes, to dim the light inside.
@export var cave_darkness: NodePath = NodePath("../Lighting/CaveDarkness")
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
## Places the outline can't push cliffs into: Vector3(x, z, radius).
var _protect: Array[Vector3] = []
## Waterfalls (Waterfall scenes) placed in the level: cliff rocks are kept off
## their path. Each {"from", "to" (local X/Z, foot to past the top), "half"
## (half their width plus room)}.
var _waterfalls: Array[Dictionary] = []
var _holes: Array[Dictionary] = []
var _cave_level: float = 0.0
## The stream (metres along it from its lake end): where it leaves the lake,
## where its pool is; the pool; and the water path (lake end to pool middle).
var _shore_along: float = 0.0
var _pool_along: float = 0.0
var _pool_centre := Vector2.ZERO
var _pool_level: float = 0.0
var _has_pool: bool = false
var _water_path := PackedVector2Array()
## Cliff height before the cave is cut out (the cave's outer roof uses it).
var _tops := PackedFloat32Array()
## 1 where a vertex is inside the cave's outline (covered or at the mouth).
var _inside := PackedByteArray()
## 1 where a vertex is inside the cave and under rock (not at the open mouth).
var _covered := PackedByteArray()
var _cave_box := Rect2()
## The cave mesh's floor height and its ceiling's height above it, per grid
## vertex (index -> metres), as built, so rocks follow the drawn surface.
var _cave_floors := {}
var _cave_ceilings := {}
## Built meshes used by the MultiMesh batches (flowers, crystals, mushrooms).
var _custom_meshes: Dictionary = {}
var _generated: Array[Node] = []
var _containers: Dictionary = {}
var _batches: Dictionary = {}
## Tint-ready copies of tree meshes (see _tinted_mesh).
var _tint_meshes: Dictionary = {}
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
		return _mesh_cave_floor(local) + global_position.y
	var cell_at := _cell_at(local)
	var a := int(cell_at.y) * _n + int(cell_at.x)
	return _tri_lerp(_heights[a], _heights[a + 1], _heights[a + _n], _heights[a + _n + 1],
		cell_at.z, cell_at.w) + global_position.y


## The grid cell under a local X/Z and where in it: Vector4(ix, iz, tx, tz),
## ix and iz whole numbers.
func _cell_at(p: Vector2) -> Vector4:
	var fx := (p.x + size * 0.5) / cell
	var fz := (p.y + size * 0.5) / cell
	var ix := clampi(floori(fx), 0, _n - 2)
	var iz := clampi(floori(fz), 0, _n - 2)
	return Vector4(ix, iz, clampf(fx - ix, 0.0, 1.0), clampf(fz - iz, 0.0, 1.0))


## A value on the rendered triangles of one grid cell (corners at (0,0),
## (1,0), (0,1), (1,1); split along the (1,0)-(0,1) diagonal like the meshes),
## so things placed with it sit exactly on what's drawn.
static func _tri_lerp(v00: float, v10: float, v01: float, v11: float, tx: float, tz: float) -> float:
	if tx + tz <= 1.0:
		return v00 + (v10 - v00) * tx + (v01 - v00) * tz
	return v11 + (v01 - v11) * (1.0 - tx) + (v10 - v11) * (1.0 - tz)


## When the editor reloads this script on an already open scene, settings
## added since the scene was opened can come up empty (Nil) instead of with
## their defaults. Gives any such Inspector setting its default value.
func _fill_missing_settings() -> void:
	var script := get_script() as Script
	if script == null:
		return
	for property in get_property_list():
		var usage: int = property["usage"]
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR):
			continue
		if property["type"] == TYPE_NIL or property["type"] == TYPE_CALLABLE or property["type"] == TYPE_OBJECT:
			continue
		var property_name: String = property["name"]
		if typeof(get(property_name)) == TYPE_NIL:
			var value: Variant = script.get_property_default_value(property_name)
			if typeof(value) != TYPE_NIL:
				set(property_name, value)


func _make_signature() -> String:
	var parts := PackedStringArray()
	for property in get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR and property["type"] != TYPE_CALLABLE:
			parts.append(str(get(property["name"])))
	return "|".join(parts)


func _rebuild() -> void:
	_fill_missing_settings()
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

	_cave_box = _cave_bounds(6.0)
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


# --- Shape of the land --------------------------------------------------------

## Flat pads around each portal (with its hole), and the places the floor's
## outline must not push its cliffs into (portals and spawn areas).
func _collect_pads() -> void:
	_pads.clear()
	_holes.clear()
	_protect.clear()
	for path in portals:
		var portal := get_node_or_null(path) as Node3D
		if portal:
			var centre := _to_local_xz(portal.global_position)
			_protect.append(Vector3(centre.x, centre.y, 30.0 + edge_margin))
	for root_path in snap_roots:
		var root := get_node_or_null(root_path)
		if root == null:
			continue
		for child in root.get_children():
			var area := child as SpawnArea
			if area == null:
				continue
			var extent := area.radius if area.shape == SpawnArea.Shape.CIRCLE else area.size.length() * 0.5
			var centre := _to_local_xz(area.global_position)
			_protect.append(Vector3(centre.x, centre.y, extent + edge_margin + 5.0))
	_collect_waterfalls()
	_find_pool()
	for i in portals.size():
		var portal := get_node_or_null(portals[i]) as Node3D
		if portal == null:
			continue
		var centre := _to_local_xz(portal.global_position)
		var footprint: Vector2 = portal.get("footprint") if "footprint" in portal else Vector2(8, 10)
		var half := footprint * 0.5
		var level := _raw(centre).x
		_pads.append({"centre": centre, "radius": half.length() + 1.0, "blend": 20.0 if i == 0 else 12.0, "height": level})
		_holes.append({"inverse": (global_transform.affine_inverse() * portal.global_transform).affine_inverse(), "half": half})
	# The cave floor is level with the ground just in front of the cliff face.
	_cave_level = _raw(cave_mouth + Vector2(0, 8)).x


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
	var dl := p.distance_to(lake_center) + _detail.get_noise_2d(p.x * 0.2, p.y * 0.2) * 5.0
	if dl < lake_radius + 30.0:
		var bed := water_level - 0.15 - lake_depth * (1.0 - pow(clampf(dl / lake_radius, 0.0, 1.0), 2.0))
		var shore := lerpf(water_level + 0.3, maxf(h, water_level + 0.3), smoothstep(lake_radius + 2.0, lake_radius + 30.0, dl))
		var wet := 1.0 - smoothstep(lake_radius - 6.0, lake_radius + 2.0, dl)
		h = lerpf(shore, bed, wet)
		sand = maxf(sand, 1.0 - smoothstep(lake_radius + 2.0, lake_radius + 7.0, dl))

	# Stream: a shallow channel in a small valley, its water rising slowly
	# upstream towards the waterfall.
	# Carved along the whole water path (pool to lake). Inside the lake it only
	# ever lowers the ground, so no bank rises out of the lake.
	var sp := _project(p, _water_path) if _water_path.size() >= 2 else Vector2(INF, 0.0)
	var w := stream_half_width
	if sp.x < w + 20.0:
		var surface := _stream_level(sp.y)
		var bed := surface - 0.15 - 0.8 * (1.0 - pow(clampf(sp.x / w, 0.0, 1.0), 2.0))
		var bank := lerpf(surface + 0.25, maxf(h, surface + 0.25), smoothstep(w + 1.5, w + 20.0, sp.x))
		var carved := lerpf(bank, bed, 1.0 - smoothstep(w - 1.2, w + 1.5, sp.x))
		h = minf(h, carved) if dl < lake_radius + 2.0 else carved
		sand = maxf(sand, 1.0 - smoothstep(w + 0.6, w + 3.0, sp.x))

	# Pool at the foot of the waterfall: a small bowl, banks above its water.
	# (Its rim never rises across the stream's channel.)
	var dp := p.distance_to(_pool_centre)
	if _has_pool and dp < POOL_RADIUS + 8.0:
		var pool_bed := _pool_level - 0.15 - 1.2 * (1.0 - pow(clampf(dp / POOL_RADIUS, 0.0, 1.0), 2.0))
		var pool_shore := lerpf(_pool_level + 0.3, maxf(h, _pool_level + 0.3), smoothstep(POOL_RADIUS + 1.0, POOL_RADIUS + 8.0, dp))
		var pool_h := lerpf(pool_shore, pool_bed, 1.0 - smoothstep(POOL_RADIUS - 1.5, POOL_RADIUS + 1.0, dp))
		h = minf(h, pool_h) if sp.x < w + 2.0 else pool_h
		sand = maxf(sand, 1.0 - smoothstep(POOL_RADIUS + 1.0, POOL_RADIUS + 3.0, dp))

	# Paths: worn dirt, slightly sunk.
	var pd := _path_distance(p)
	var path_t := 1.0 - smoothstep(2.2, 4.2, pd + _detail.get_noise_2d(p.x * 0.6, p.y * 0.6) * 1.0)
	dirt = maxf(dirt, path_t)
	h -= 0.2 * path_t

	# Edge: rising rocky cliffs along the floor's irregular outline (stepped,
	# with ledges, their height varying along the edge), and the rocky spur
	# the cave is cut into.
	var cliff := 1.0 - smoothstep(0.0, edge_band, _edge(p))
	var spur_shape := _spur(p)
	var spur := 1.0 - smoothstep(0.0, spur_shape.y, spur_shape.x)
	var rocky := maxf(cliff, spur)
	h += maxf(_cliff_profile(cliff, p) * _cliff_height_at(p), pow(spur, 1.3) * cave_cliff_height) \
		+ rocky * _detail.get_noise_2d(p.x * 0.25, p.y * 0.25) * 7.0
	rock = maxf(rock, smoothstep(0.3, 0.65, rocky))
	return Vector4(h, dirt, rock, sand)


## Distance inside the top of the edge cliffs (negative beyond it): the cliff
## rises from its foot at `edge_band` to its top at 0. The outline is a
## rounded square pushed in by noise, so the cliffs curve in and out in bays
## and outcrops, never a straight wall. Near portals and spawn areas it isn't
## pushed in.
func _edge(p: Vector2) -> float:
	var r := pow(pow(absf(p.x), 6.0) + pow(absf(p.y), 6.0), 1.0 / 6.0)
	var n := 0.55 + _detail.get_noise_2d(p.x * 0.1 + 1300.0, p.y * 0.1) * 0.8 \
		+ _detail.get_noise_2d(p.x * 0.4 - 800.0, p.y * 0.4) * 0.35
	return size * 0.5 - r - EDGE_INSET * clampf(n, 0.0, 1.0) * _edge_protection(p)


## 0 at portals and spawn areas (the outline may not move in there), rising
## to 1 within 50 m of them.
func _edge_protection(p: Vector2) -> float:
	var t := 1.0
	for spot: Vector3 in _protect:
		t = minf(t, smoothstep(spot.z, spot.z + 50.0, p.distance_to(Vector2(spot.x, spot.y))))
	return t


## Cliff height along the edge: from about 0.6x to 1.4x `cliff_height`.
func _cliff_height_at(p: Vector2) -> float:
	return cliff_height * (0.6 + 0.8 * (_detail.get_noise_2d(p.x * 0.075 + 400.0, p.y * 0.075) * 0.5 + 0.5))


## Stepped rise from the cliff foot (0) to its top (1): steep rock faces with
## ledges between them, the steps wandering along the edge.
func _cliff_profile(t: float, p: Vector2) -> float:
	var x := pow(t, 1.4) * 3.0 + _detail.get_noise_2d(p.x * 0.2 + 900.0, p.y * 0.2) * 0.35
	var step := floorf(x)
	return clampf((step + smoothstep(0.2, 0.8, x - step)) / 3.0, 0.0, 1.0)


## The cave's cliff spur at a point: Vector2(distance outside its area, width
## of its rock side here). Around the cave mouth the side is a steep rock face.
func _spur(p: Vector2) -> Vector2:
	var d := _rect_distance(p, cave_cliff) + _detail.get_noise_2d(p.x * 0.12 + 70.0, p.y * 0.12) * 7.0
	var width := lerpf(MOUTH_SLOPE, cave_cliff_slope, smoothstep(12.0, 40.0, absf(p.x - cave_mouth.x)))
	return Vector2(d, width)


func _build_heights() -> void:
	_n = int(round(size / cell)) + 1
	_heights.resize(_n * _n)
	_tops.resize(_n * _n)
	_inside.resize(_n * _n)
	_covered.resize(_n * _n)
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
			_covered[i] = 0
			var cave := 0.0
			if _cave_box.has_point(p) and _cave_sdf(p) < 0.0:
				_inside[i] = 1
				var floor_h := _cave_floor(p)
				if h > floor_h + _cave_height(p) + CAVE_ROOF_MIN:
					# Under the rock: the cave's own floor.
					_covered[i] = 1
					cave = 1.0
				elif h > floor_h + 0.3:
					# The mouth, where the vault breaks out of the cliff face: the
					# rock is open down to the cave floor.
					dirt = maxf(dirt, 0.7)
				h = minf(h, floor_h)
			_heights[i] = h
			_weights[i] = Color(dirt, v.z, v.w, cave)


## Flat-shaded terrain: every triangle gets its own normal and one palette
## colour, like the KayKit low-poly models. Split into square chunks (one
## mesh each, so what's behind the camera is culled); one collider for all.
func _build_terrain() -> void:
	var chunks := {}
	var faces := PackedVector3Array()
	for iz in _n - 1:
		for ix in _n - 1:
			var centre := _grid_point(ix, iz) + Vector2(cell, cell) * 0.5
			if _in_hole(centre) or _is_cave_quad(ix, iz):
				continue
			var key := Vector2i(floori(float(ix) / GROUND_CHUNK_CELLS), floori(float(iz) / GROUND_CHUNK_CELLS))
			if not chunks.has(key):
				chunks[key] = MeshData.new()
			var data: MeshData = chunks[key]
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
				data.tri(p0, p1, p2, _ground_color(weights, normal, (p0 + p1 + p2) / 3.0))
				faces.append(p0)
				faces.append(p1)
				faces.append(p2)
	var ground := Node3D.new()
	ground.name = "Ground"
	_add_generated(ground, self)
	for key: Vector2i in chunks:
		var data: MeshData = chunks[key]
		var instance := MeshInstance3D.new()
		instance.name = "Chunk_%d_%d" % [key.x, key.y]
		instance.mesh = _mesh(data.vertices, data.normals, data.colors)
		ground.add_child(instance)
	_add_generated(_trimesh_body("GroundBody", faces, 1), self)


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
## wander instead of following the round shapes (the mouth too, so the
## opening is irregular).
func _cave_warp(p: Vector2) -> float:
	var f := 1.0 / CAVE_SCALE
	return (_detail.get_noise_2d(p.x * 0.6 * f + 300.0, p.y * 0.6 * f) * 2.2
		+ _detail.get_noise_2d(p.x * 2.0 * f - 150.0, p.y * 2.0 * f) * 0.6) * CAVE_SCALE * cave_roughness


## How far inside one shape a point is (negative outside). Narrow passages
## get less of the warp, so they never pinch shut.
static func _shape_inside(p: Vector2, shape: PackedFloat32Array, warp: float) -> float:
	var d := _segment_distance(p, Vector2(shape[0], shape[1]), Vector2(shape[2], shape[3]))
	return shape[4] - d + warp * clampf(shape[4] / (6.0 * CAVE_SCALE), 0.35, 1.0)


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


## Uneven cave floor; level at the mouth, so it meets the ground outside.
func _cave_floor(p: Vector2) -> float:
	var f := 1.0 / CAVE_SCALE
	var bumps := _detail.get_noise_2d(p.x * 1.1 * f + 210.0, p.y * 1.1 * f) * 0.5 + _detail.get_noise_2d(p.x * 2.6 * f, p.y * 2.6 * f - 90.0) * 0.2
	return _cave_level + bumps * CAVE_SCALE * 0.5 * smoothstep(5.0, 25.0, cave_mouth.y - p.y) * cave_roughness


## True on the cave's own floor (under the rock), where heights come from
## _cave_floor() rather than the terrain grid.
func _on_cave_floor(p: Vector2) -> bool:
	return _cave_box.has_point(p) and _cave_sdf(p) < cell * 0.5 and _is_covered(p)


## True if the cliff's rock is over the cave's vault here (not the open mouth).
func _is_covered(p: Vector2) -> bool:
	if _tops.is_empty():
		return false
	return _grid_lerp(_tops, p) > _cave_floor(p) + _cave_height(p) + CAVE_ROOF_MIN


## A grid array (e.g. _tops) interpolated at a local X/Z.
func _grid_lerp(values: PackedFloat32Array, p: Vector2) -> float:
	var fx := (p.x + size * 0.5) / cell
	var fz := (p.y + size * 0.5) / cell
	var ix := clampi(floori(fx), 0, _n - 2)
	var iz := clampi(floori(fz), 0, _n - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var top := lerpf(values[iz * _n + ix], values[iz * _n + ix + 1], tx)
	var bottom := lerpf(values[(iz + 1) * _n + ix], values[(iz + 1) * _n + ix + 1], tx)
	return lerpf(top, bottom, tz)


## A terrain quad the cave replaces: one with a corner under the rock.
func _is_cave_quad(ix: int, iz: int) -> bool:
	if _covered.is_empty():
		return false
	var a := iz * _n + ix
	return _covered[a] == 1 or _covered[a + 1] == 1 or _covered[a + _n] == 1 or _covered[a + _n + 1] == 1


## Direction into the cave (away from the nearest wall).
func _cave_inward(p: Vector2) -> Vector2:
	var g := Vector2(_cave_sdf(p + Vector2(1.0, 0)) - _cave_sdf(p - Vector2(1.0, 0)),
		_cave_sdf(p + Vector2(0, 1.0)) - _cave_sdf(p - Vector2(0, 1.0)))
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
		var fall := clampf(shape[4] * 0.55, 4.0, 16.0)
		var t := clampf(inside / fall, 0.0, 1.0)
		var top: float = shape[5] * (1.0 + _detail.get_noise_2d(p.x * 0.14 + 40.0, p.y * 0.14) * 0.25 * cave_roughness)
		best = maxf(best, top * (1.0 - pow(1.0 - t, 2.2)))
	if best <= 0.0:
		return 0.0
	# Lumpy rock.
	var f := 1.0 / CAVE_SCALE
	var bumps := _detail.get_noise_2d(p.x * 1.2 * f + 77.0, p.y * 1.2 * f) * 0.9 + _detail.get_noise_2d(p.x * 3.0 * f - 20.0, p.y * 3.0 * f) * 0.35
	best += bumps * minf(best * 0.35, 1.2 * CAVE_SCALE) * cave_roughness
	# Hanging rock where the ceiling is high.
	var hang := _detail.get_noise_2d(p.x * 2.2 * f + 500.0, p.y * 2.2 * f)
	if hang > 0.45:
		best -= (hang - 0.45) * 6.0 * CAVE_SCALE * smoothstep(8.0, 16.0, best) * cave_roughness
	# Near the mouth the vault is ragged, so the opening isn't a neat arch.
	var near_mouth := 1.0 - smoothstep(6.0, 20.0, p.distance_to(cave_mouth))
	if near_mouth > 0.0:
		best += _detail.get_noise_2d(p.x * 1.6 + 640.0, p.y * 1.6) * 3.5 * near_mouth * cave_roughness
	# Always head room away from the walls.
	if deepest > 3.0:
		best = maxf(best, 4.0)
	return maxf(best, 0.05)


## The cave: an outer rocky shell (the cliff seen from the forest) and an
## inner shell (the cave's walls and ceiling), both meeting the ground at the
## cave's edge. The mouth is where the vault breaks out of the cliff face:
## there the inner shell rises to meet the cliff surface, and rough rock
## faces close the seam where it meets the open ground.
func _build_cave() -> void:
	if cave_shapes.is_empty():
		return
	var half := size * 0.5
	var x0 := clampi(floori((_cave_box.position.x + half) / cell), 0, _n - 2)
	var x1 := clampi(ceili((_cave_box.end.x + half) / cell), 1, _n - 1)
	var z0 := clampi(floori((_cave_box.position.y + half) / cell), 0, _n - 2)
	var z1 := clampi(ceili((_cave_box.end.y + half) / cell), 1, _n - 1)

	# Per vertex: the cave floor and the ceiling's height above it. The vault
	# keeps its full height at the open mouth too, so the opening is as tall
	# as the cave there (the rock above ends in a lip at the vault's edge
	# instead of sloping down into the opening).
	_cave_floors.clear()
	_cave_ceilings.clear()
	var floors := _cave_floors
	var ceilings := _cave_ceilings
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var p := _grid_point(ix, iz)
			var i := iz * _n + ix
			if _inside[i] == 0:
				floors[i] = _cave_floor(p)
				ceilings[i] = 0.0
			else:
				floors[i] = _heights[i]
				ceilings[i] = maxf(_cave_floor(p) + _cave_height(p) - _heights[i], 0.0)

	var inside := MeshData.new()
	var outside := MeshData.new()
	for iz in range(z0, z1):
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
					# Never below the vault: at the mouth the rock ends in a lip
					# on the opening's edge rather than dipping into it.
					over.append(Vector3(v.x, maxf(_tops[tri[k]], fl + hc), v.z))
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

	# Rock faces around the mouth: wherever a cave quad borders open ground,
	# close the gap between the inner shell's edge and the cliff surface. They
	# follow the ragged edge of the opening, so there is no neat arch.
	for iz in range(z0, z1):
		for ix in range(x0, x1):
			if not _is_cave_quad(ix, iz):
				continue
			var a := iz * _n + ix
			# Each edge: its two corners and the neighbouring quad across it.
			for edge in [[a, a + 1, 0, -1], [a + _n, a + _n + 1, 0, 1], [a, a + _n, -1, 0], [a + 1, a + _n + 1, 1, 0]]:
				var nx: int = ix + edge[2]
				var nz: int = iz + edge[3]
				if nx < 0 or nz < 0 or nx >= _n - 1 or nz >= _n - 1 or _is_cave_quad(nx, nz):
					continue
				var ea: int = edge[0]
				var eb: int = edge[1]
				if _inside[ea] == 0 and _inside[eb] == 0:
					continue  # Along the cave's sides: buried under the cliff.
				var pa := _vertex(ea)
				var pb := _vertex(eb)
				var ia := Vector3(pa.x, floors[ea] + ceilings[ea], pa.z)
				var ib := Vector3(pb.x, floors[eb] + ceilings[eb], pb.z)
				var oa := Vector3(pa.x, maxf(_tops[ea], ia.y), pa.z)
				var ob := Vector3(pb.x, maxf(_tops[eb], ib.y), pb.z)
				if oa.y - ia.y < 0.01 and ob.y - ib.y < 0.01:
					continue
				# Face the open ground (the neighbouring quad). The face hangs down
				# from the cliff surface, so (oa, ob, ia) faces along -UP x edge.
				var out := Vector3(edge[2], 0.0, edge[3])
				if Vector3.UP.cross(pb - pa).dot(out) < 0.0:
					_add_tri(outside, oa, ob, ia, ROCK_COLOR)
					_add_tri(outside, ob, ib, ia, ROCK_COLOR)
				else:
					_add_tri(outside, oa, ia, ob, ROCK_COLOR)
					_add_tri(outside, ob, ia, ib, ROCK_COLOR)

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
		light.light_energy = 1.2
		light.omni_range = shape[4] + 10.0
		light.omni_attenuation = 1.4
		light.position = Vector3(at.x, _cave_floor(at) + minf(shape[5] * 0.45, 9.0), at.y)
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
		a.y = minf(a.y, cave_mouth.y - 7.0)
		b.y = minf(b.y, cave_mouth.y - 7.0)
		var collider := CollisionShape3D.new()
		var centre := (a + b) * 0.5
		if a.distance_to(b) < 0.1:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = shape[4] + 2.5 * CAVE_SCALE
			cylinder.height = shape[5] + 4.0 * CAVE_SCALE
			collider.shape = cylinder
		else:
			var box := BoxShape3D.new()
			box.size = Vector3(shape[4] * 2.0 + 5.0 * CAVE_SCALE, shape[5] + 4.0 * CAVE_SCALE, a.distance_to(b))
			collider.shape = box
			collider.rotation.y = atan2(b.x - a.x, b.y - a.y)
		collider.position = Vector3(centre.x, _cave_level + shape[5] * 0.5 + 2.0, centre.y)
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

## The water: the lake and the pool (flat, at their own levels) and the
## stream, one strip of water along `_water_path` from inside the pool to
## inside the lake. The strip overlaps both, its ends sitting just under
## their surfaces and fading out there, so there's no gap and no seam.
func _build_water() -> void:
	var root := _root(water_root)
	var material := load(WATER_MATERIAL) as Material
	var data := WaterData.new()
	_water_disc(data, lake_center, lake_radius + 6.0, water_level)
	if _has_pool:
		_water_disc(data, _pool_centre, POOL_RADIUS + 1.5, _pool_level)
		_stream_strip(data)
	var surface := MeshInstance3D.new()
	surface.name = "Water"
	surface.mesh = _water_mesh(data, material)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(surface, root)
	var body := _water_body("WaterSurface", root)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data.vertices)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)


## Water triangles being collected: flat-shaded, with the data the water
## shader reads (UV and COLOR, see shaders/world/floor1_water.gdshader).
class WaterData:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()

	func tri(points: Array, tex: Array, flow: Array) -> void:
		var p0: Vector3 = points[0]
		var p1: Vector3 = points[1]
		var p2: Vector3 = points[2]
		var normal := (p2 - p0).cross(p1 - p0).normalized()
		if normal.y < 0.0:
			normal = -normal
		for k in 3:
			vertices.append(points[k])
			normals.append(normal)
			uvs.append(tex[k])
			colors.append(flow[k])


func _water_mesh(data: WaterData, material: Material) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	arrays[Mesh.ARRAY_COLOR] = data.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


## A flat, still disc of water (its edge ends under the banks).
func _water_disc(data: WaterData, centre: Vector2, radius: float, level: float) -> void:
	var still := Color(0.0, 0.25, 0.0, 1.0)
	var segments := 48
	var middle := Vector3(centre.x, level, centre.y)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var e0 := middle + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var e1 := middle + Vector3(cos(a1), 0.0, sin(a1)) * radius
		data.tri([middle, e1, e0], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [still, still, still])


## The stream: one strip along `_water_path`, from inside the pool to inside
## the lake. Its surface follows _stream_level() (the pool's level down to the
## lake's); inside the pool and the lake it lies just under their surface and
## fades out, so the three meet without a gap, a step or a double layer.
## UV.y grows towards the lake, so the streaks drift that way.
func _stream_strip(data: WaterData) -> void:
	var total := _line_length(_water_path)
	var half := stream_half_width + 1.2
	var rows: Array = []
	var along := 0.0
	while true:
		var at := _point_along(_water_path, along)
		var ahead := _point_along(_water_path, minf(along + 0.5, total)) - _point_along(_water_path, maxf(along - 0.5, 0.0))
		var side := Vector2(-ahead.y, ahead.x).normalized()
		var level := _stream_level(along)
		# Streaks only where it flows: they fade out towards the lake and the pool.
		var flow := smoothstep(lake_radius - 4.0, lake_radius + 2.0, at.distance_to(lake_center)) \
			* smoothstep(POOL_RADIUS - 2.0, POOL_RADIUS + 4.0, at.distance_to(_pool_centre))
		var row := []
		for k in STREAM_COLUMNS + 1:
			var offset := lerpf(-half, half, float(k) / STREAM_COLUMNS)
			var spot := at + side * offset
			# Over the lake's / pool's water disc the strip lies just under it and
			# is hidden, so there is only ever one layer of water: no double
			# layer (darker patch) and no gap where they meet.
			# (From 1 m in from the disc's edge, so the strip's fade happens under
			# the disc and never leaves thinner water at its edge.)
			var covered := spot.distance_to(lake_center) < lake_radius + 6.0 - 1.0 \
				or spot.distance_to(_pool_centre) < POOL_RADIUS + 1.5 - 1.0
			var y := level - 0.02 if covered else level
			var color := Color(flow, 0.25, 0.0, 0.0 if covered else 1.0)
			row.append([Vector3(spot.x, y, spot.y), Vector2(offset, -along), color])
		rows.append(row)
		if along >= total:
			break
		along = minf(along + 1.0, total)
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for k in STREAM_COLUMNS:
			data.tri([a[k][0], a[k + 1][0], b[k][0]], [a[k][1], a[k + 1][1], b[k][1]], [a[k][2], a[k + 1][2], b[k][2]])
			data.tri([a[k + 1][0], b[k + 1][0], b[k][0]], [a[k + 1][1], b[k + 1][1], b[k][1]], [a[k + 1][2], b[k + 1][2], b[k][2]])


## Water level along `_water_path` (metres from its lake end): the lake's
## level up to the shore, then rising `stream_drop` per metre up to the
## pool's level.
func _stream_level(along: float) -> float:
	return water_level + clampf(along - _shore_along, 0.0, maxf(_pool_along - _shore_along, 0.0)) * stream_drop


## Where the stream leaves the lake, and its pool at the foot of the edge
## cliff (where the stream reaches it), then the stream's water path: the
## stream from its lake end to the pool's middle.
func _find_pool() -> void:
	var total := _line_length(stream)
	var along := 0.0
	while along < total and _point_along(stream, along).distance_to(lake_center) < lake_radius:
		along += 0.5
	_shore_along = along
	var foot := total
	while along < total:
		if _edge(_point_along(stream, along)) < edge_band:
			foot = along
			break
		along += 0.5
	_has_pool = stream.size() >= 2
	_pool_along = maxf(foot - POOL_RADIUS * 0.6, _shore_along)
	_pool_centre = _point_along(stream, _pool_along)
	_pool_level = _stream_level(_pool_along)
	_water_path = PackedVector2Array()
	var walked := 0.0
	for i in stream.size():
		if i > 0:
			walked += stream[i - 1].distance_to(stream[i])
		if walked >= _pool_along:
			break
		_water_path.append(stream[i])
	_water_path.append(_pool_centre)


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
		if p.distance_to(pad["centre"]) < pad["radius"] + 2.0:
			return &""
	if _in_hole(p):
		return &""
	var cave := _cave_sdf(p) if _cave_box.has_point(p) else INF
	if cave < 0.0:
		if not _is_covered(p):
			return &""  # The open mouth.
		if cave < -5.0:
			return &"cave"
		return &"cave_wall" if cave < -0.4 else &""
	if cave < 2.0:
		return &""  # The cave's walls and the ground right at its edge.
	# Nothing on the edge cliffs and the cave's cliff spur, and only grass in a
	# clear strip in front of them (no trees, rocks, bushes or logs).
	var edge := _edge(p)
	var spur := _spur(p)
	if edge < edge_band or spur.x < spur.y:
		return &""
	if edge < edge_band + edge_margin or spur.x < spur.y + edge_margin:
		return &"edge_clear"
	var dl := p.distance_to(lake_center)
	if dl < lake_radius + 2.0:
		return &"lake"
	var sp := _project(p, _water_path) if _water_path.size() >= 2 else Vector2(INF, 0.0)
	if sp.x < stream_half_width + 2.0 or (_has_pool and p.distance_to(_pool_centre) < POOL_RADIUS + 2.0):
		return &"stream"
	if _path_distance(p) < 3.8:
		return &"path"
	if not _pads.is_empty() and p.distance_to(_pads[0]["centre"]) < clearing_radius:
		return &"clearing"
	if p.distance_to(plain_center) < plain_radius:
		return &"plain"
	return &"forest"


func _clump(p: Vector2) -> float:
	return clampf(0.6 + _noise.get_noise_2d(p.x * 2.5 + 300.0, p.y * 2.5) * 1.2, 0.1, 1.3)


## Terrain normal at a point (from the height grid).
func _normal(p: Vector2) -> Vector3:
	var hl := _h(p + Vector2(-cell, 0))
	var hr := _h(p + Vector2(cell, 0))
	var hu := _h(p + Vector2(0, -cell))
	var hd := _h(p + Vector2(0, cell))
	return Vector3(hl - hr, 2.0 * cell, hu - hd).normalized()


## Height of the outside surface as drawn at a local X/Z: over the cave the
## cliff's rock above it, elsewhere the ground.
func _outer_h(p: Vector2) -> float:
	var c := _cell_at(p)
	if _cave_floors.is_empty() or not _is_cave_quad(int(c.x), int(c.y)):
		return _h(p)
	var a := int(c.y) * _n + int(c.x)
	var v := PackedFloat32Array()
	for i: int in [a, a + 1, a + _n, a + _n + 1]:
		var vault := float(_cave_floors.get(i, _heights[i])) + float(_cave_ceilings.get(i, 0.0))
		v.append(maxf(_tops[i], vault))
	return _tri_lerp(v[0], v[1], v[2], v[3], c.z, c.w)


## Normal of the outside surface (see _outer_h).
func _outer_normal(p: Vector2) -> Vector3:
	var hl := _outer_h(p + Vector2(-cell, 0))
	var hr := _outer_h(p + Vector2(cell, 0))
	var hu := _outer_h(p + Vector2(0, -cell))
	var hd := _outer_h(p + Vector2(0, cell))
	return Vector3(hl - hr, 2.0 * cell, hu - hd).normalized()


## True if a cliff rock (bounding sphere at `centre`, radius `r`) stays out of
## the cave: wherever it is over the cave's outline (its mouth included) it
## must be above the cave's ceiling, and it must leave the way in clear.
func _clear_of_cave(centre: Vector3, r: float) -> bool:
	var at := Vector2(centre.x, centre.z)
	if not _cave_box.grow(r + 1.0).has_point(at):
		return true
	var low := centre.y - r
	for k in 9:
		var q := at if k == 8 else at + Vector2.from_angle(TAU * k / 8.0) * r
		if _cave_sdf(q) < 0.5 and low < _mesh_vault(q) + 0.3:
			return false
	return not (_in_entrance_walkway(at, r) and low < _cave_level + CAVE_WALKWAY_HEADROOM)


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
	var steps := int(size / tree_spacing)
	for ix in steps:
		for iz in steps:
			var p := Vector2(-half + (ix + rng.randf()) * tree_spacing, -half + (iz + rng.randf()) * tree_spacing)
			var roll := rng.randf()
			var zone := _zone(p)
			var slope := _normal(p).y
			var tree_chance := 0.0
			match zone:
				&"forest":
					tree_chance = forest_density * _clump(p) * (0.45 if _path_distance(p) < 10.0 else 1.0)
				&"plain":
					tree_chance = 0.015
			if slope < 0.7:
				tree_chance = 0.0
			if roll < tree_chance:
				_place_tree(rng, p)

	var candidates: Array[Vector2] = []
	var undergrowth_steps := int(size / UNDERGROWTH_SPACING)
	for ix in undergrowth_steps:
		for iz in undergrowth_steps:
			candidates.append(Vector2(-half + (ix + rng.randf()) * UNDERGROWTH_SPACING, -half + (iz + rng.randf()) * UNDERGROWTH_SPACING))
	for p in candidates:
		var zone := _zone(p)
		if zone == &"":
			continue
		var slope := _normal(p).y
		var clump := _clump(p)
		var bush_chance := {&"forest": 0.22, &"plain": 0.07, &"clearing": 0.05}.get(zone, 0.0) as float
		if rng.randf() < bush_chance * clump and slope > 0.6:
			_place_bush(rng, p + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
		var rock_chance := {&"forest": 0.035, &"cave": 0.12, &"cave_wall": 0.5, &"plain": 0.01, &"clearing": 0.02}.get(zone, 0.0) as float
		if rng.randf() < rock_chance:
			var q := p + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
			if zone == &"cave_wall":
				_place_cave_rock(rng, q)
			else:
				_place_rock(rng, q, rng.randf() < 0.12, "CaveRocks" if zone == &"cave" else "Rocks")
		if zone == &"cave" and rng.randf() < 0.03:
			_place_spire(rng, p)
		# Rubble along the cave walls.
		if zone == &"cave_wall" and rng.randf() < 0.45:
			_place_rubble(rng, p + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8)))
		# Glowing crystals and mushrooms (decoration only).
		var crystal_chance := {&"cave_wall": 0.28, &"cave": 0.04}.get(zone, 0.0) as float
		if rng.randf() < crystal_chance:
			_place_crystal(rng, p + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)), zone == &"cave_wall")
		var plant_chance := {&"cave_wall": 0.3, &"cave": 0.08}.get(zone, 0.0) as float
		if rng.randf() < plant_chance:
			_place_glow_plant(rng, p + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8)))
		if zone == &"forest" and rng.randf() < 0.012 and slope > 0.85:
			_place_log(rng, p)

	_scatter_cliff_rocks(rng)
	_scatter_ground_cover(rng)


## Rock skin by height up the cliff (0 = foot, 1 = top, more = along the top):
## [up to this height, main layer [[tier, chance], ...], fine layer [...]].
## Mostly medium and small rocks, only a few large ones; rubble at the foot.
const CLIFF_BANDS := [
	[0.15, [["medium", 0.6], ["large", 0.02]], [["rubble", 0.5], ["small", 0.45]]],
	[1.0, [["medium", 0.85], ["large", 0.07]], [["small", 0.8]]],
	[INF, [["medium", 0.75], ["large", 0.08]], [["small", 0.6]]],
]
## Inside the floor, steep slopes get the same rocks (smaller tiers).
const STEEP_TIERS := [["rubble", 0.3], ["small", 0.3], ["medium", 0.2]]
## The cave's walls and ceiling: mostly small and medium, a few large.
const CAVE_SKIN_TIERS := [["small", 0.52], ["medium", 0.42], ["large", 0.03]]


## Covers the edge cliffs and the cave's cliff spur densely with many
## smaller KayKit rocks (a main layer of medium and a few large ones, and a
## fine layer of small rocks and rubble), randomly turned, overlapping and half
## buried, so they read as rough rock; steep slopes inside the floor get some
## too. Then the same for the cave's walls and ceiling.
func _scatter_cliff_rocks(rng: RandomNumberGenerator) -> void:
	# One spot per grid cell, so the grid spacing follows from the density.
	var density := maxf(cliff_rock_density, 0.01)
	_scatter_cliff_layer(rng, sqrt(1.0 / (density * CLIFF_MAIN_SHARE)), 1)
	_scatter_cliff_layer(rng, sqrt(1.0 / (density * (1.0 - CLIFF_MAIN_SHARE))), 2)
	_scatter_cave_skin(rng)


## One layer of the cliff skin on a grid of `spacing`; `layer` picks the
## tiers from CLIFF_BANDS (1 = main, 2 = fine).
func _scatter_cliff_layer(rng: RandomNumberGenerator, spacing: float, layer: int) -> void:
	var half := size * 0.5
	var steps := int(size / spacing)
	# Steep slopes inside the floor keep their own density (one try per 3 x 3 m),
	# whatever the cliff density.
	var steep_try := minf((spacing / 3.0) * (spacing / 3.0), 1.0)
	for ix in steps:
		for iz in steps:
			var p := Vector2(-half + (ix + rng.randf()) * spacing, -half + (iz + rng.randf()) * spacing)
			var at := _cliff_position(p)
			if at.x <= 0.0:
				# Inside the floor: only steep slopes (not the clear strip).
				if layer == 1 and rng.randf() < steep_try:
					var zone := _zone(p)
					if zone in [&"forest", &"plain", &"clearing"] and _normal(p).y < 0.72:
						var steep_tier := _pick_tier(STEEP_TIERS, rng.randf())
						if steep_tier != "":
							_place_steep_rock(rng, p, steep_tier)
				continue
			if is_nan(at.y):
				continue  # Behind the top of the cliff or over the cave: never seen.
			var tiers: Array = []
			for band: Array in CLIFF_BANDS:
				if at.x <= float(band[0]):
					tiers = band[layer]
					break
			# Steep faces get more rocks per spot, so they're covered as densely
			# as gentler parts.
			var count := clampi(ceili(1.0 / maxf(_outer_normal(p).y, 0.1)), 1, 10)
			for k in count:
				var q := p + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * spacing
				var tier := _pick_tier(tiers, rng.randf(), true)
				var q_at := _cliff_position(q)
				if tier != "" and q_at.x > 0.0 and not is_nan(q_at.y):
					_place_cliff_rock(rng, q, tier, q_at.y)


## Where a point is on the cliffs: Vector2(height up the cliff: 0 at its foot,
## 1 at its top, more along the top; metres in from the foot). The second is
## NAN where no rocks go: far behind the top, or on top of the spur over the cave.
func _cliff_position(p: Vector2) -> Vector2:
	var edge := _edge(p)
	var spur := _spur(p)
	var u_edge := 1.0 - edge / edge_band
	var u_spur := 1.0 - spur.x / spur.y
	if u_edge >= u_spur:
		return Vector2(u_edge, edge_band - edge if edge > -4.0 else NAN)
	return Vector2(u_spur, spur.y - spur.x if spur.x > -4.0 else NAN)


## Picks a tier: `roll` (0-1) against the chances. With `weights`, the chances
## are only relative (something is always picked).
static func _pick_tier(tiers: Array, roll: float, weights: bool = false) -> String:
	if weights:
		var total := 0.0
		for entry: Array in tiers:
			total += float(entry[1])
		roll *= total
	for entry: Array in tiers:
		roll -= float(entry[1])
		if roll < 0.0:
			return entry[0]
	return ""


## A uniform scale for a wall rock of its tier (`spec`), kept so the rock's
## longest side is within `size_range` (metres, min / max).
func _rock_scale(rng: RandomNumberGenerator, model: String, spec: Array, size_range: Vector2) -> float:
	var longest := maxf(KitPiece.model_aabb(model).get_longest_axis_size(), 0.01)
	var low := maxf(size_range.x, 0.01) / longest
	var high := maxf(size_range.y, size_range.x) / longest
	return clampf(rng.randf_range(spec[1], spec[2]), low, maxf(low, high))


## A rock turned at random (any direction, uniform scale `s`), its centre
## placed so it sticks out of the surface at `surface` (normal `outward`, to the open side)
## by at most `reach`; the rest is buried.
func _skin_xform(rng: RandomNumberGenerator, model: String, s: float, surface: Vector3, outward: Vector3, reach: float) -> Transform3D:
	var box := KitPiece.model_aabb(model)
	var r := box.size.length() * 0.5 * s
	var turn := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * s)
	var centre := surface - outward * (r - reach)
	return Transform3D(turn, centre - turn * box.get_center())


## One cliff skin rock of `tier` at `p`, `behind_foot` metres in from the
## cliff's foot: half buried in the cliff, never reaching out past its foot,
## inside the map and away from the cave, its way in and the portals.
func _place_cliff_rock(rng: RandomNumberGenerator, p: Vector2, tier: String, behind_foot: float) -> void:
	var spec: Array = CLIFF_TIERS[tier]
	var model := NATURE % _pick(rng, spec[0])
	var s := _rock_scale(rng, model, spec, cliff_rock_size)
	var box := KitPiece.model_aabb(model)
	var r := box.size.length() * 0.5 * s
	if r * 0.8 > behind_foot + 1.0:
		return  # Would stick out past the cliff foot into the floor.
	if absf(p.x) + r > size * 0.5 or absf(p.y) + r > size * 0.5:
		return
	for pad in _pads:
		if p.distance_to(pad["centre"]) < float(pad["radius"]) + r + 6.0:
			return
	if _has_pool and p.distance_to(_pool_centre) < POOL_RADIUS + r + 1.0:
		return  # Not in the pool.
	if _on_waterfall(p, r):
		return  # Not over a waterfall: it runs down the bare cliff face.
	# On the outside rock as drawn (over the cave that's the cliff above it).
	var xform := _skin_xform(rng, model, s, Vector3(p.x, _outer_h(p), p.y), _outer_normal(p), 2.0 * r * (1.0 - cliff_rock_sink))
	if not _clear_of_cave(xform.origin + xform.basis * box.get_center(), r):
		return
	match tier:
		"rubble":
			_queue("CliffRubble", 48.0, model, xform, false, 90.0)
		"small":
			_queue("CliffSmall", 48.0, model, xform, false, 140.0)
		_:
			_queue("CliffRocks", 64.0, model, xform, true, 400.0)
	# Solid where the player can reach them (near the foot); small rocks there
	# only block spawn areas.
	if behind_foot - r < 5.0:
		_add_shape_box(_colliders if tier == "medium" or tier == "large" else _scenery, xform, box, 0.7)


## The cave's walls and ceiling covered densely with smaller rocks, on a grid
## over the cave's floor plan (more per spot where the walls are steep). They
## have no collision (the cave's own rock collides, and ore veins find the
## walls through them), keep head room above the floor, and stay thin at the
## foot of the walls.
func _scatter_cave_skin(rng: RandomNumberGenerator) -> void:
	if cave_shapes.is_empty():
		return
	# One spot per grid cell (on the floor plan, more on steep walls), so the
	# grid spacing follows from the density.
	var spacing := sqrt(1.0 / maxf(cave_rock_density, 0.01))
	var nx := int(_cave_box.size.x / spacing) + 1
	var nz := int(_cave_box.size.y / spacing) + 1
	for ix in nx:
		for iz in nz:
			var p := _cave_box.position + Vector2(ix + rng.randf(), iz + rng.randf()) * spacing
			if not _on_cave_wall_mesh(p):
				continue
			var slope := _vault_gradient(p).length()
			var count := clampi(ceili(sqrt(1.0 + slope * slope)), 1, 10)
			for k in count:
				var q := p + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * spacing
				if _on_cave_wall_mesh(q):
					_place_cave_skin_rock(rng, q, _pick_tier(CAVE_SKIN_TIERS, rng.randf(), true))


## Slope of the cave's inner surface (its walls and ceiling) at `p`.
func _vault_gradient(p: Vector2) -> Vector2:
	var e := 0.8
	var dx := _vault(p + Vector2(e, 0)) - _vault(p - Vector2(e, 0))
	var dz := _vault(p + Vector2(0, e)) - _vault(p - Vector2(0, e))
	return Vector2(dx, dz) / (2.0 * e)


## Height of the cave's inner surface (its walls and ceiling) at `p`, as drawn.
func _vault(p: Vector2) -> float:
	return _mesh_vault(p)


## True where the cave mesh has walls or a ceiling over `p` (down to the
## very foot of the walls, where they meet the floor).
func _on_cave_wall_mesh(p: Vector2) -> bool:
	if _cave_floors.is_empty():
		return false
	var c := _cell_at(p)
	if not _is_cave_quad(int(c.x), int(c.y)):
		return false
	return _mesh_vault(p) - _mesh_cave_floor(p) > 0.02


## Height of the cave mesh's floor at `p` (on its triangles).
func _mesh_cave_floor(p: Vector2) -> float:
	return _mesh_cave_value(p, false)


## Height of the cave mesh's walls / ceiling at `p` (on its triangles).
func _mesh_vault(p: Vector2) -> float:
	return _mesh_cave_value(p, true)


func _mesh_cave_value(p: Vector2, vault: bool) -> float:
	var c := _cell_at(p)
	var a := int(c.y) * _n + int(c.x)
	var v := PackedFloat32Array()
	for i: int in [a, a + 1, a + _n, a + _n + 1]:
		if not _cave_floors.has(i):
			return _cave_floor(p) + (_cave_height(p) if vault else 0.0)
		v.append(float(_cave_floors[i]) + (float(_cave_ceilings[i]) if vault else 0.0))
	return _tri_lerp(v[0], v[1], v[2], v[3], c.z, c.w)


## One rock on the cave's walls or ceiling, half buried in the rock and
## turned at random. Hanging rocks keep head room above the floor (more along
## the way in); at the foot of the walls only thin ones.
func _place_cave_skin_rock(rng: RandomNumberGenerator, p: Vector2, tier: String) -> void:
	if tier == "":
		return
	var floor_h := _mesh_cave_floor(p)
	var ceiling := _mesh_vault(p) - floor_h
	var g := _vault_gradient(p)
	var inward := Vector3(g.x, -1.0, g.y).normalized()  # Into the cave.
	var walkway := _in_entrance_walkway(p, 0.0)
	var wall_foot := ceiling < CAVE_WALL_FOOT
	if wall_foot:
		tier = "small"
	var spec: Array = CLIFF_TIERS[tier]
	var model := NATURE % _pick(rng, spec[0])
	var s := _rock_scale(rng, model, spec, cave_rock_size)
	var r1 := KitPiece.model_aabb(model).size.length() * 0.5  # Radius at scale 1.
	var reach := 2.0 * r1 * s * (1.0 - cave_rock_sink)
	if wall_foot:
		# Thin at the foot of the walls (still uniform scale: just smaller).
		var limit := 0.3 if walkway else CAVE_WALL_FOOT_REACH
		if reach > limit:
			s *= limit / reach
			reach = limit
	else:
		# The lowest point the rock could reach (its bounding sphere, buried
		# into the rock away from the open cave).
		var low := floor_h + ceiling - inward.y * (r1 * s - reach) - r1 * s
		if low < floor_h + (CAVE_WALKWAY_HEADROOM if walkway else CAVE_HEADROOM):
			return
	# The open side of this surface is the inside of the cave.
	var xform := _skin_xform(rng, model, s, Vector3(p.x, floor_h + ceiling, p.y), inward, reach)
	_queue("CaveSkin", 24.0, model, xform, false, 80.0)


## Finds the Waterfall scenes placed in the level (anywhere under this
## node's parent) and the strip of cliff each runs down: from just in front
## of its foot to past its top (its measured cliff face, see Snap To Cliff),
## as wide as the water plus some room. Move a waterfall, then press Rebuild.
func _collect_waterfalls() -> void:
	_waterfalls.clear()
	var level := get_parent()
	if level == null:
		return
	for node in level.find_children("*", "", true, false):
		var fall := node as Waterfall
		if fall == null:
			continue
		var back := -fall.global_basis.z
		back.y = 0.0
		if back.length() < 0.01:
			continue
		back = back.normalized()
		var reach := Waterfall.RUN + 3.0
		for point in fall.cliff_profile:
			reach = maxf(reach, -point.x + Waterfall.RUN + 3.0)
		_waterfalls.append({
			"from": _to_local_xz(fall.global_position - back * 1.0),
			"to": _to_local_xz(fall.global_position + back * reach),
			"half": fall.width * 0.5 * 1.15 + 1.0,
		})


## True if a rock (centre `p`, radius `r`) would sit on a waterfall's path.
func _on_waterfall(p: Vector2, r: float) -> bool:
	for fall: Dictionary in _waterfalls:
		if _segment_distance(p, fall["from"], fall["to"]) < float(fall["half"]) + r:
			return true
	return false


## A rock on a steep slope inside the floor (same rocks, smaller tiers),
## claiming its spot like the other rocks.
func _place_steep_rock(rng: RandomNumberGenerator, p: Vector2, tier: String) -> void:
	var spec: Array = CLIFF_TIERS[tier]
	var model := NATURE % _pick(rng, spec[0])
	var s := rng.randf_range(spec[1], spec[2])
	var box := KitPiece.model_aabb(model)
	var radius := maxf(box.size.x, box.size.z) * 0.5 * s
	if _path_distance(p) < radius + 1.5 or not _clear_of_edges(p, radius) or _in_entrance_walkway(p, radius) \
			or _on_waterfall(p, radius) or not _claim(p, radius * 0.8):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -box.position.y * s - box.size.y * s * 0.3, 0.6)
	var small := tier == "small" or tier == "rubble"
	_queue("CliffRubble" if small else "CliffRocks", 48.0, model, xform, true, 160.0 if small else 220.0)
	_add_shape_box(_scenery if small else _colliders, xform, box, 0.8)


## True if a circle at `p` stays out of the clear strip along the edge cliffs
## and the cave's cliff spur (`edge_margin` in front of their rock).
func _clear_of_edges(p: Vector2, radius: float) -> bool:
	var edge := _edge(p)
	var spur := _spur(p)
	return edge - radius >= edge_band + edge_margin and spur.x - radius >= spur.y + edge_margin


## True if a circle at `p` reaches into the walkway kept clear through the
## cave's entrance: from the mouth along the first cave shape (the entrance
## tunnel) to the second (the entry hall), so nothing solid blocks the way in.
func _in_entrance_walkway(p: Vector2, radius: float) -> bool:
	if cave_shapes.is_empty() or cave_shapes[0].size() < 6:
		return false
	var tunnel := cave_shapes[0]
	var start := Vector2(tunnel[0], tunnel[1])
	var end := Vector2(tunnel[2], tunnel[3])
	if cave_shapes.size() > 1 and cave_shapes[1].size() >= 6:
		end = Vector2(cave_shapes[1][0], cave_shapes[1][1])
	return _segment_distance(p, start, end) < ENTRANCE_WALKWAY + radius


## A forest tree: any KayKit tree model, `tree_height` tall with a
## `trunk_width` trunk where the model allows (uniform scale only; stout
## models stay smaller so their trunk isn't too thick). Turned and leaning a
## little at random, slightly tinted, its trunk sunk below the lowest ground
## around it. Some get rocks, bushes or a log around the base.
func _place_tree(rng: RandomNumberGenerator, p: Vector2) -> void:
	var tree_name := _pick_tree(rng)
	var model := NATURE % tree_name
	var height := KitPiece.model_aabb(model).size.y
	var trunk_d: float = (TREE_MODELS[tree_name] as Array)[0]
	var s_min := maxf(tree_height.x / height, trunk_width.x / trunk_d)
	var s_max := minf(tree_height.y / height, trunk_width.y / trunk_d)
	if s_min > s_max:
		# Too stout to be that tall: the trunk width decides.
		s_min = trunk_width.x / trunk_d
		s_max = minf(trunk_width.y / trunk_d, tree_height.y / height)
	var s := rng.randf_range(s_min, maxf(s_min, s_max))
	var trunk_r := trunk_d * 0.5 * s
	# Trunks keep a wide gap to each other; the claim itself hugs the trunk, so
	# rocks, bushes and logs can lie right at its base.
	if not _clear_of_edges(p, trunk_r) or not _is_free(p, trunk_r + TREE_GAP) or not _claim(p, trunk_r + TREE_ROOM):
		return
	# A slight lean in a random direction.
	var lean_dir := rng.randf() * TAU
	var lean := deg_to_rad(rng.randf_range(0.0, 4.0))
	# Sink the trunk below the lowest ground around it (plus what the lean
	# lifts its edge), so no side of it ever floats.
	var centre_h := _h(p)
	var lowest := centre_h
	for k in 8:
		var angle := TAU * k / 8.0
		lowest = minf(lowest, _h(p + Vector2(cos(angle), sin(angle)) * trunk_r))
	var sink := -(centre_h - lowest) - trunk_r * sin(lean) - 0.4
	var xform := _xform(p, rng.randf() * TAU, s, sink, 0.0)
	xform.basis = Basis(Vector3(cos(lean_dir), 0.0, sin(lean_dir)), lean) * xform.basis
	# Slight colour variation: a little lighter or darker, a little warmer or cooler.
	var value := rng.randf_range(0.86, 1.06)
	var tint := Color(value * rng.randf_range(0.94, 1.06), value * rng.randf_range(0.96, 1.04), value * rng.randf_range(0.92, 1.04))
	_queue("Trees", 64.0, model, xform, true, 600.0, tint)
	# Trunk collider (tall, so nothing spawns on top of it).
	var trunk := CylinderShape3D.new()
	trunk.radius = trunk_r * 0.9
	trunk.height = height * s * 0.5
	_add_shape(_colliders, trunk, Transform3D(Basis.IDENTITY, Vector3(p.x, centre_h + sink + trunk.height * 0.5, p.y)))
	if rng.randf() < TREE_BASE_CHANCE:
		_place_tree_base(rng, p, trunk_r)


## Picks a tree model by its weight in TREE_MODELS.
func _pick_tree(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for tree_name: String in TREE_MODELS:
		total += float((TREE_MODELS[tree_name] as Array)[1])
	var roll := rng.randf() * total
	for tree_name: String in TREE_MODELS:
		roll -= float((TREE_MODELS[tree_name] as Array)[1])
		if roll <= 0.0:
			return tree_name
	return TREE_MODELS.keys()[0]


## One to three rocks, bushes or a log around a tree's base (each only where
## it fits, like everything else).
func _place_tree_base(rng: RandomNumberGenerator, p: Vector2, trunk_r: float) -> void:
	for i in rng.randi_range(1, 3):
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var roll := rng.randf()
		if roll < 0.45:
			_place_rock(rng, p + dir * (trunk_r + rng.randf_range(1.2, 2.8)), rng.randf() < 0.15)
		elif roll < 0.85:
			_place_bush(rng, p + dir * (trunk_r + rng.randf_range(1.5, 3.0)))
		else:
			_place_log(rng, p + dir * (trunk_r + rng.randf_range(3.0, 4.0)))


func _place_bush(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := NATURE % _pick(rng, BUSHES)
	var s := rng.randf_range(1.6, 2.6)
	var radius := _radius(model, s)
	if _path_distance(p) < radius + 1.5 or not _clear_of_edges(p, radius) or not _claim(p, radius):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.1, 0.6)
	_queue("Bushes", 48.0, model, xform, true, 140.0)
	var body := CylinderShape3D.new()
	body.radius = radius * 0.8
	body.height = 1.2 * s
	_add_shape(_scenery, body, Transform3D(Basis.IDENTITY, xform.origin + Vector3.UP * body.height * 0.5))


func _place_rock(rng: RandomNumberGenerator, p: Vector2, big: bool, group: String = "Rocks") -> void:
	var model := NATURE % _pick(rng, ROCKS_BIG if big else ROCKS_SMALL)
	var s := rng.randf_range(1.5, 2.4) if big else rng.randf_range(1.2, 2.2)
	var radius := _radius(model, s)
	var ceiling := _cave_height(p)
	if ceiling > 0.0 and KitPiece.model_aabb(model).size.y * s > ceiling - 0.4:
		return
	if _path_distance(p) < radius + 1.5 or (group != "CaveRocks" and not _clear_of_edges(p, radius)) \
			or _in_entrance_walkway(p, radius) or not _claim(p, radius):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.15 * s, 1.0)
	_queue(group, 48.0, model, xform, true, 160.0 if group == "CaveRocks" else 220.0)
	var box := KitPiece.model_aabb(model)
	_add_shape_box(_colliders if box.size.length() * s > 1.6 else _scenery, xform, box, 0.8)


## Rocks along the cave's inside walls, half sunk into the floor and wall,
## always fitting under the ceiling.
func _place_cave_rock(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := NATURE % _pick(rng, ROCKS_WALL)
	var s := rng.randf_range(0.8, 1.6)
	var box := KitPiece.model_aabb(model)
	if box.size.y * s > _cave_height(p) - 0.4 or _in_entrance_walkway(p, _radius(model, s)) \
			or not _claim(p, _radius(model, s) * 0.8):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.2 * s, 1.0)
	_queue("CaveRocks", 48.0, model, xform, true, 160.0)
	_add_shape_box(_colliders, xform, box, 0.8)


## Small KayKit rocks and stone chunks along the cave walls.
func _place_rubble(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := RESOURCE % _pick(rng, ["Stone_Chunks_Small", "Stone_Chunks_Large"]) if rng.randf() < 0.5 \
		else NATURE % _pick(rng, ["Rock_2_A", "Rock_2_B", "Rock_1_A", "Rock_1_B"])
	var s := rng.randf_range(1.0, 1.8)
	var box := KitPiece.model_aabb(model)
	var ceiling := _cave_height(p)
	if (ceiling > 0.0 and box.size.y * s > ceiling - 0.4) or _in_entrance_walkway(p, _radius(model, s)) \
			or not _claim(p, _radius(model, s) * 0.8):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.05 * s, 1.0)
	_queue("CaveRocks" if p.y < cave_mouth.y else "Rocks", 48.0, model, xform, true, 160.0)
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
	_queue("Crystals", 48.0, "crystal_%s_%d" % [tint, rng.randi() % 3], xform, false, 110.0)
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
	_queue("GlowPlants", 48.0, "mushrooms_%d" % (rng.randi() % 2), xform, false, 90.0)
	var blocker := CylinderShape3D.new()
	blocker.radius = 0.22 * s
	blocker.height = 0.3 * s
	_add_shape(_scenery, blocker, Transform3D(Basis.IDENTITY, xform.origin + Vector3.UP * blocker.height * 0.5))


## Tall rock spire in the cave, only where the ceiling is high enough.
func _place_spire(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := NATURE % _pick(rng, ROCKS_SPIRE)
	var s := rng.randf_range(1.6, 2.6)
	var box := KitPiece.model_aabb(model)
	if _cave_height(p) < box.size.y * s + 1.0 or _in_entrance_walkway(p, _radius(model, s)) \
			or not _claim(p, _radius(model, s)):
		return
	var xform := _xform(p, rng.randf() * TAU, s, -0.2 * s, 0.0)
	_queue("CaveRocks", 48.0, model, xform, true, 160.0)
	_add_shape_box(_colliders, xform, box, 0.8)


func _place_log(rng: RandomNumberGenerator, p: Vector2) -> void:
	var model := RESOURCE % _pick(rng, LOGS)
	var s := rng.randf_range(3.0, 3.8)
	var box := KitPiece.model_aabb(model)
	# A log is long: it claims a circle of half its length.
	if _path_distance(p) < box.size.z * s * 0.5 + 1.5 or not _clear_of_edges(p, box.size.z * s * 0.5) \
			or not _claim(p, box.size.z * s * 0.5):
		return
	# The log model is centred on its origin: lift it so it lies slightly sunk,
	# along the slope.
	var xform := _xform(p, rng.randf() * TAU, s, 0.0, 1.0)
	xform.origin += xform.basis.y.normalized() * 0.2 * s
	_queue("Logs", 48.0, model, xform, true, 180.0)
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
			var chance := {&"plain": 0.8, &"clearing": 0.55, &"forest": 0.3, &"edge_clear": 0.3, &"path": 0.04}.get(zone, 0.0) as float
			if roll < chance * grass_density and _normal(p).y > 0.75 and _is_free(p, 0.15):
				_queue("Grass", 32.0, NATURE % _pick(rng, GRASS), _xform(p, rng.randf() * TAU, rng.randf_range(0.9, 1.6), -0.03, 0.5), false, 45.0)
			if zone == &"plain" and rng.randf() < 0.3:
				var q := p + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
				if _is_free(q, 0.1):
					_queue("Flowers", 32.0, "flower", _xform(q, rng.randf() * TAU, rng.randf_range(0.8, 1.3), -0.02, 0.5), false, 45.0,
						FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()])

	# Reeds in the shallows around the lake and along the stream banks.
	for i in 2250:
		var angle := rng.randf() * TAU
		var r := lake_radius + rng.randf_range(-7.0, 3.0)
		var p := lake_center + Vector2(cos(angle), sin(angle)) * r
		if _project(p, stream).x < stream_half_width + 1.0 or not _is_free(p, 0.15):
			continue
		if rng.randf() < 0.6:
			_queue("Reeds", 48.0, NATURE % _pick(rng, REEDS), _xform(p, rng.randf() * TAU, rng.randf_range(1.6, 2.4), -0.05, 0.0), false, 70.0)
	var total := _line_length(stream)
	var along := 0.0
	while along < minf(total, _pool_along):
		along += rng.randf_range(0.6, 1.6)
		var at := _point_along(stream, along)
		if at.distance_to(lake_center) < lake_radius + 2.0:
			continue
		var ahead := _point_along(stream, minf(along + 0.5, total)) - _point_along(stream, maxf(along - 0.5, 0.0))
		var side := Vector2(-ahead.y, ahead.x).normalized() * (stream_half_width + rng.randf_range(0.4, 2.4)) * (1.0 if rng.randf() < 0.5 else -1.0)
		if _is_free(at + side, 0.15):
			_queue("Reeds", 48.0, NATURE % _pick(rng, REEDS), _xform(at + side, rng.randf() * TAU, rng.randf_range(1.4, 2.1), -0.05, 0.0), false, 70.0)


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
			var tinted: bool = batch["group"] == "Trees"
			multimesh.use_colors = tinted or batch["path"] == "flower"
			# Tinted models get copies of their materials that take the
			# instance colour (the shared imported materials stay as they are).
			multimesh.mesh = _tinted_mesh(part["mesh"]) if tinted else part["mesh"]
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
			# A little slack, so a chunk at the edge of its range doesn't flicker
			# in and out as the player moves back and forth.
			instance.visibility_range_end_margin = batch["distance"] * 0.08
			if batch["group"] in CAVE_GROUPS:
				instance.layers = CAVE_RENDER_LAYER  # No sunlight inside the cave.
			if not batch["shadows"]:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(instance)
	_batches.clear()
	_tint_meshes.clear()


## A copy of `mesh` whose materials multiply in the instance colour (cached
## per mesh for this build).
func _tinted_mesh(mesh: Mesh) -> Mesh:
	if _tint_meshes.has(mesh):
		return _tint_meshes[mesh]
	var copy := mesh.duplicate() as ArrayMesh
	if copy == null:
		return mesh  # Not an ArrayMesh: drawn untinted.
	for i in copy.get_surface_count():
		var source := mesh.surface_get_material(i) as BaseMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as BaseMaterial3D
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		copy.surface_set_material(i, material)
	_tint_meshes[mesh] = copy
	return copy


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
	head_material.vertex_color_is_srgb = true
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
