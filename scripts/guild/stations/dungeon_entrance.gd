@tool
class_name DungeonEntrance
extends KitPiece
## Stone archway over stairs that go down into a pit, built from Medieval
## Village and Fantasy Props pieces (never stretched): brick floor tiles
## around the pit, brick walls lining it with a closed gate at the back,
## stone steps, wooden railings along the sides, and two brick pillars with
## a timber beam and mounted torches.
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
## Text on the arch's beam.
@export var sign_text: String = "DUNGEON"
## Not empty: the way is closed. E shows this text and nothing loads.
@export var locked_text: String = ""
## Prompt for E at the arch.
@export var prompt: String = "Descend into the dungeon"

## Where the flame sits on the mounted torch (Torch_Metal, model space).
const TORCH_HEAD := Vector3(0.0, 0.37, 0.27)
const TORCH_MODEL := "Torch_Metal"
## Stone steps (Stairs_Exterior_Straight: 2 wide, 1 m rise over 2 m, high
## end toward model -Z), four in a row: steps rise 4 m over 8 m, scaled
## evenly with the pit depth.
const STEP_MODEL := "Stairs_Exterior_Straight"
const STAIRS_RISE := 4.0
const STAIRS_RUN := 8.0
const STEP_MODULES := 4
const WALL := 4.0
const MODULE := 2.0
const TILE_MODEL := "Floor_Brick"
const TILE_DEPTH := 0.02
const WALL_MODEL := "Wall_UnevenBrick_Straight"
const GATE_WALL := "Wall_UnevenBrick_Door_Round"
const GATE_DOOR := "Door_8_Round"
const RAILING_MODEL := "Balcony_Simple_Straight"
const BEAM_MODEL := "Roof_Log"
## Walls sit this far below ground so their tops don't fight the tiles.
const WALL_SINK := 0.15

var _entered: bool = false


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	var stairs_scale := pit_depth / STAIRS_RISE
	var run := STAIRS_RUN * stairs_scale
	var module_w := MODULE * stairs_scale
	var ow := maxf(ceilf(opening_width / GRID) * GRID, ceilf(module_w * 2.0 / GRID) * GRID)
	var od := maxf(ceilf(opening_depth / GRID) * GRID, ceilf((run + 1.6) / GRID) * GRID)
	var fx := maxf(snappedf(footprint.x, GRID), ow + 2.0 * GRID)
	var fz := maxf(snappedf(footprint.y, GRID), od + GRID)
	var z_back := -fz * 0.5
	var z_front := z_back + od
	var half_ow := ow * 0.5

	# Floor tiles around the opening (top at y = 0) and at the pit bottom.
	var stone := mv(TILE_MODEL)
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

	# Pit walls: brick walls (brick face toward the pit), tops just below
	# ground, with a band of the same brick up to the top.
	var wall_y := -WALL - WALL_SINK
	var depth := KitWall.BODY_DEPTH
	for sx in [-1.0, 1.0]:
		_wall_run(Vector3(sx * half_ow, wall_y, z_back), Vector3(0, 0, 1), od, -90.0 * sx)
		add_collision_box(Vector3(depth, pit_depth + 1.0, od), Vector3(sx * half_ow, -(pit_depth + 1.0) * 0.5, (z_back + z_front) * 0.5))
	if absf(ow - WALL) < 0.01:
		# Closed gate in the middle, brick either side and above.
		var brick := KitWall.brick_material()
		_wall_piece(GATE_WALL, Vector3(0, wall_y, z_back), 0.0)
		for sx in [-1.0, 1.0]:
			add_box(Vector3(1.0, KitWall.WALL_H, KitWall.BODY), Vector3(sx * 1.5, wall_y + KitWall.WALL_H * 0.5, z_back), brick, false)
		add_box(Vector3(ow, WALL - KitWall.WALL_H, KitWall.BODY), Vector3(0, wall_y + (KitWall.WALL_H + WALL) * 0.5, z_back), brick, false)
		var door := mv(GATE_DOOR)
		var door_w := model_aabb(door).size.x
		add_model_xform(door, Transform3D(Basis.IDENTITY, Vector3(-door_w * 0.5, wall_y, z_back)))
	else:
		_wall_run(Vector3(-half_ow, wall_y, z_back), Vector3(1, 0, 0), ow, 0.0)
	add_collision_box(Vector3(ow, pit_depth + 1.0, depth), Vector3(0, -(pit_depth + 1.0) * 0.5, z_back))
	_wall_run(Vector3(-half_ow, wall_y, z_front), Vector3(1, 0, 0), ow, 180.0)

	# Stone steps from the front edge down toward the back: rows of step
	# modules (turned so they climb toward +Z), as many across as fit.
	var step := mv(STEP_MODEL)
	var step_src := model_aabb(step)
	var across := maxi(floori((ow - 0.4) / module_w), 1)
	for i in STEP_MODULES:
		var top := -i * stairs_scale
		var cz := z_front - (i + 0.5) * module_w
		for k in across:
			var cx := (k - (across - 1) * 0.5) * module_w
			add_model(step, stairs_scale, Vector3(cx, top - step_src.size.y * stairs_scale, cz), 180.0)
	var depth_per := run / steps
	var rise_per := pit_depth / steps
	var stairs_w := across * module_w
	for i in steps - 1:
		var top := -(i + 1) * rise_per
		var h := pit_depth + top
		add_collision_box(Vector3(stairs_w, h, depth_per), Vector3(0, top - h * 0.5, z_front - (i + 0.5) * depth_per))

	# Wooden railings along both sides of the pit, on the surround.
	var rail := mv(RAILING_MODEL)
	var rail_src := model_aabb(rail)
	for sx in [-1.0, 1.0]:
		var rail_x: float = sx * (half_ow + rail_src.size.z * 0.5 + 0.05)
		var d := 0.0
		while d < od - 0.01:
			add_model(rail, 1.0, Vector3(rail_x, 0, z_back + d + MODULE * 0.5), 90.0)
			d += MODULE
		add_collision_box(Vector3(rail_src.size.z, rail_src.size.y, od), Vector3(rail_x, rail_src.size.y * 0.5, (z_back + z_front) * 0.5))

	# Archway at the top of the stairs: two brick pillars, a timber beam, torches.
	var post := KitPillar.post_footprint(arch_height)
	var pillar_w := post.x
	var pillar_d := post.y
	var pillar_x := half_ow + pillar_w * 0.5
	var pillar_z := z_front + pillar_d * 0.5
	var torch_path := fp(TORCH_MODEL)
	var torch_src := model_aabb(torch_path)
	var torch_h := 0.7
	var torch_s := torch_h / torch_src.size.y
	for sx in [-1.0, 1.0]:
		KitPillar.add_post(self, arch_height, 1, Vector3(sx * pillar_x, 0, pillar_z))
		add_collision_box(Vector3(pillar_w, arch_height, pillar_d), Vector3(sx * pillar_x, arch_height * 0.5, pillar_z))
		# Mounted torch on the pillar's front, with flames (emission only,
		# no light).
		var torch := add_model_sized(torch_path, Vector3(sx * pillar_x, 2.0, z_front + pillar_d + torch_src.size.z * torch_s * 0.5), torch_h)
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
	# Beam: the timber roof log (10.7 m long along Z), turned along X and
	# scaled evenly so it spans both pillars.
	var beam := mv(BEAM_MODEL)
	var beam_src := model_aabb(beam)
	var beam_len := pillar_x * 2.0 + pillar_w
	var beam_scale := beam_len / beam_src.size.z
	var beam_h := beam_src.size.y * beam_scale
	var beam_d := beam_src.size.x * beam_scale
	add_model(beam, beam_scale, Vector3(0, arch_height, pillar_z), 90.0)
	add_collision_box(Vector3(beam_len, beam_h, beam_d), Vector3(0, arch_height + beam_h * 0.5, pillar_z))
	add_label(sign_text, Vector3(0, arch_height + beam_h * 0.5, pillar_z + beam_d * 0.5 + 0.03), 64, Color(1.0, 0.8, 0.55))

	# Trigger at the bottom of the stairs (runtime only).
	if not Engine.is_editor_hint() and auto_enter and locked_text.is_empty():
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


## Brick walls from `start` along `dir` (2 m modules), brick face turned
## by `rot_y`, with the band of brick above.
func _wall_run(start: Vector3, dir: Vector3, length: float, rot_y: float) -> void:
	var d := 0.0
	while d < length - 0.01:
		_wall_piece(WALL_MODEL, start + dir * (d + MODULE * 0.5), rot_y)
		d += MODULE
	var along := dir.abs() * length
	var size := Vector3(maxf(along.x, KitWall.BODY), WALL - KitWall.WALL_H, maxf(along.z, KitWall.BODY))
	var mid := start + dir * length * 0.5
	add_box(size, mid + Vector3(0, (KitWall.WALL_H + WALL) * 0.5, 0), KitWall.brick_material(), false)


## One wall module, its brick face (model +Z) turned by `rot_y` and its
## body centred on `at`.
func _wall_piece(model: String, at: Vector3, rot_y: float) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y))
	add_model_xform(mv(model), Transform3D(basis, at - basis * Vector3(0, 0, KitWall.BODY_CENTRE)))


func get_interaction_text() -> String:
	return locked_text if not locked_text.is_empty() else prompt


func interact(player: Player) -> void:
	if not locked_text.is_empty():
		player.notified.emit(locked_text)
		return
	_enter()


func _on_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		_enter()


func _enter() -> void:
	if _entered:
		return
	_entered = true
	SceneManager.change_scene(target_scene, target_spawn)
