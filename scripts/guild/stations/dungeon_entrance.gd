@tool
class_name DungeonEntrance
extends KitPiece
## Stone archway over stairs that go down into a pit, built from KayKit
## pieces (never stretched): floor tiles around the pit, 1 m dungeon walls
## lining it with a portcullis at the back, stone stairs, barriers along
## the sides, and two pillars with a stone beam and mounted torches.
## Walking to the bottom (or pressing E at the arch) loads the dungeon scene.
## Origin at ground level in the middle of the footprint; you walk in from
## +Z (through the arch) and descend toward -Z. The pit sits at the back
## (-Z) end of the footprint. The piece brings its own floor, so leave its
## footprint free of other floors. Sizes snap to the 2 m grid and grow to
## fit the stairs.

@export_group("Size")
## Snaps to the grid; at least the opening + 4 m wide and + 2 m deep.
@export var footprint: Vector2 = Vector2(8.0, 10.0)
## Snaps up to the grid (at least 4 m: the stairs are 4 m wide at 3.2 m deep).
@export var opening_width: float = 4.0
## Snaps up to the grid; at least the stairs' run + 1.6 m.
@export var opening_depth: float = 8.0
## The stairs scale evenly with the depth (3.2 m: 4 m wide, 6.4 m long).
@export var pit_depth: float = 3.2
## Number of step colliders.
@export_range(4, 30) var steps: int = 12
## Pillar height (the pillars scale evenly).
@export var arch_height: float = 4.2
@export_group("Destination")
@export_file("*.tscn") var target_scene: String = "res://scenes/world/dungeon_floor_1.tscn"
@export var target_spawn: StringName = &"from_guild"
## Load the dungeon automatically when the player reaches the bottom.
@export var auto_enter: bool = true

## Where the flame sits on the KayKit mounted torch (model space).
const TORCH_HEAD := Vector3(0.0, 0.62, 0.31)
## KayKit stairs_long: 5 m wide, steps rise 4 m over 8 m; high end at z 0.
const STAIRS_WIDTH := 5.0
const STAIRS_RISE := 4.0
const STAIRS_RUN := 8.0
const WALL := 4.0
const HALF := 2.0
const TILE_DEPTH := 0.15
## Walls sit this far below ground so their tops don't fight the tiles.
const WALL_SINK := 0.15

var _entered: bool = false


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	var stairs_scale := pit_depth / STAIRS_RISE
	var run := STAIRS_RUN * stairs_scale
	var ow := maxf(ceilf(opening_width / GRID) * GRID, ceilf(STAIRS_WIDTH * stairs_scale / GRID) * GRID)
	var od := maxf(ceilf(opening_depth / GRID) * GRID, ceilf((run + 1.6) / GRID) * GRID)
	var fx := maxf(snappedf(footprint.x, GRID), ow + 2.0 * GRID)
	var fz := maxf(snappedf(footprint.y, GRID), od + GRID)
	var z_back := -fz * 0.5
	var z_front := z_back + od
	var half_ow := ow * 0.5

	# Floor tiles around the opening (top at y = 0) and at the pit bottom.
	var stone := kk("floor_tile_small")
	var rng := make_rng(2)
	for ix in roundi(fx / GRID):
		for iz in roundi(fz / GRID):
			var cx := -fx * 0.5 + (ix + 0.5) * GRID
			var cz := z_back + (iz + 0.5) * GRID
			var in_pit := absf(cx) < half_ow and cz < z_front
			var y := -pit_depth if in_pit else 0.0
			add_model(stone, 1.0, Vector3(cx, y - TILE_DEPTH, cz), 90.0 * rng.randi_range(0, 3))
	var slab := 0.3
	var side_w := (fx - ow) * 0.5
	for sx in [-1.0, 1.0]:
		add_collision_box(Vector3(side_w, slab, fz), Vector3(sx * (half_ow + side_w * 0.5), -slab * 0.5, 0))
	add_collision_box(Vector3(ow, slab, fz * 0.5 - z_front), Vector3(0, -slab * 0.5, (z_front + fz * 0.5) * 0.5))
	add_collision_box(Vector3(ow, slab, od), Vector3(0, -pit_depth - slab * 0.5, (z_back + z_front) * 0.5))

	# Pit walls: KayKit dungeon walls, tops just below ground, facing in.
	var wall_y := -WALL - WALL_SINK
	for sx in [-1.0, 1.0]:
		_wall_run(Vector3(sx * half_ow, wall_y, z_back), Vector3(0, 0, 1), od, -90.0 * sx)
		add_collision_box(Vector3(1.0, pit_depth + 1.0, od), Vector3(sx * half_ow, -(pit_depth + 1.0) * 0.5, (z_back + z_front) * 0.5))
	if absf(ow - WALL) < 0.01:
		add_model(kk("wall_gated"), 1.0, Vector3(0, wall_y, z_back))
	else:
		_wall_run(Vector3(-half_ow, wall_y, z_back), Vector3(1, 0, 0), ow, 0.0)
	add_collision_box(Vector3(ow, pit_depth + 1.0, 1.0), Vector3(0, -(pit_depth + 1.0) * 0.5, z_back))
	_wall_run(Vector3(-half_ow, wall_y, z_front), Vector3(1, 0, 0), ow, 180.0)

	# Stone stairs from the front edge down toward the back.
	var turn := Basis(Vector3.UP, PI).scaled_local(Vector3.ONE * stairs_scale)
	add_model_xform(kk("stairs_long"), Transform3D(turn, Vector3(0, -pit_depth, z_front)))
	var depth_per := run / steps
	var rise_per := pit_depth / steps
	for i in steps - 1:
		var top := -(i + 1) * rise_per
		var h := pit_depth + top
		add_collision_box(Vector3(ow - 1.0, h, depth_per), Vector3(0, top - h * 0.5, z_front - (i + 0.5) * depth_per))

	# Stone barriers along both sides of the pit, on the surround.
	for sx in [-1.0, 1.0]:
		_barrier_run(Vector3(sx * (half_ow + 0.25), 0, z_back), od, sx)
		add_collision_box(Vector3(0.5, 1.1, od), Vector3(sx * (half_ow + 0.25), 0.55, (z_back + z_front) * 0.5))

	# Archway at the top of the stairs: two pillars, a stone beam, torches.
	var pillar_scale := arch_height / WALL
	var pillar_w := 1.5 * pillar_scale
	var pillar_x := half_ow + pillar_w * 0.5
	var pillar_z := z_front + pillar_w * 0.5
	for sx in [-1.0, 1.0]:
		add_model(kk("pillar"), pillar_scale, Vector3(sx * pillar_x, 0, pillar_z))
		add_collision_box(Vector3(pillar_w * 0.8, arch_height, pillar_w * 0.8), Vector3(sx * pillar_x, arch_height * 0.5, pillar_z))
		# Mounted KayKit torch on the pillar's front, with flames (emission
		# only, no light).
		var torch_h := 0.7
		var torch := add_model_sized(kk("torch_mounted"), Vector3(sx * pillar_x, 2.0, z_front + pillar_w + torch_h * 0.29), torch_h)
		var flame := GPUParticles3D.new()
		flame.amount = 18
		flame.lifetime = 0.7
		flame.process_material = load("res://materials/effects/fire_flame_process.tres")
		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.3)
		quad.material = load("res://materials/effects/fire_particle.tres")
		flame.draw_pass_1 = quad
		flame.position = torch.transform * TORCH_HEAD
		add_generated(flame)
	# Beam: the KayKit stone barrier with end columns (4 x 1.4 x 0.7 m),
	# scaled evenly so its columns sit on the pillars.
	var beam_scale := pillar_x * 2.0 / (WALL - 0.7)
	add_model(kk("barrier_column"), beam_scale, Vector3(0, arch_height, pillar_z))
	add_collision_box(Vector3(pillar_x * 2.0 + 0.7 * beam_scale, 1.4 * beam_scale, 0.7 * beam_scale), Vector3(0, arch_height + 0.7 * beam_scale, pillar_z))
	add_label("DUNGEON", Vector3(0, arch_height + 0.75 * beam_scale, pillar_z + 0.35 * beam_scale + 0.03), 64, Color(1.0, 0.8, 0.55))

	# Trigger at the bottom of the stairs (runtime only).
	if not Engine.is_editor_hint() and auto_enter:
		var trigger := Area3D.new()
		trigger.collision_layer = 0
		trigger.collision_mask = LAYER_WORLD
		trigger.monitorable = false
		var bottom := od - run
		var shape := BoxShape3D.new()
		shape.size = Vector3(ow - 1.0, 2.0, bottom)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		trigger.add_child(collider)
		trigger.position = Vector3(0, -pit_depth + 1.0, z_back + bottom * 0.5)
		trigger.body_entered.connect(_on_trigger_body_entered)
		add_generated(trigger)


## Dungeon walls from `start` along `dir` (4 m pieces, a 2 m half for the rest).
func _wall_run(start: Vector3, dir: Vector3, length: float, rot_y: float) -> void:
	var d := 0.0
	while d < length - 0.01:
		var piece := WALL if length - d >= WALL - 0.02 else HALF
		add_model(kk("wall" if piece == WALL else "wall_half"), 1.0, start + dir * (d + piece * 0.5), rot_y)
		d += piece


## Stone barriers along Z from `start` (4 m pieces, a 2 m half for the rest).
func _barrier_run(start: Vector3, length: float, side: float) -> void:
	var d := 0.0
	while d < length - 0.01:
		var piece := WALL if length - d >= WALL - 0.02 else HALF
		add_model(kk("barrier" if piece == WALL else "barrier_half"), 1.0, start + Vector3(0, 0, d + piece * 0.5), -90.0 * side)
		d += piece


func get_interaction_text() -> String:
	return "Descend into the dungeon"


func interact(_player: Player) -> void:
	_enter()


func _on_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		_enter()


func _enter() -> void:
	if _entered:
		return
	_entered = true
	SceneManager.change_scene(target_scene, target_spawn)
