@tool
class_name DungeonEntrance
extends KitPiece
## Big stone archway over stairs that go down into a pit. Walking to the
## bottom (or pressing E at the arch) loads the dungeon scene.
## Origin at ground level in the middle of the footprint; you walk in from
## +Z (through the arch) and descend toward -Z. The piece brings its own
## stone surround, so leave its footprint free of other floors.

@export_group("Size")
@export var footprint: Vector2 = Vector2(6.0, 8.0)
@export var opening_width: float = 2.4
@export var opening_depth: float = 5.2
@export var pit_depth: float = 3.2
@export_range(4, 30) var steps: int = 12
@export var arch_height: float = 4.2
@export_group("Destination")
@export_file("*.tscn") var target_scene: String = "res://scenes/main.tscn"
@export var target_spawn: StringName = &"from_guild"
## Load the dungeon automatically when the player reaches the bottom.
@export var auto_enter: bool = true

var _entered: bool = false


func _build() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	var half_x := footprint.x * 0.5
	var half_z := footprint.y * 0.5
	var ow := opening_width * 0.5
	var z_front := opening_depth * 0.5   # Top of the stairs (arch side).
	var z_back := -opening_depth * 0.5
	var slab := 0.3
	var stone := mat("stone")
	var wall := mat("stone_wall")
	var pillar := mat("stone_pillar")

	# Surround floor around the opening (top at y = 0).
	add_box(Vector3(half_x - ow, slab, footprint.y), Vector3(-(ow + half_x) * 0.5, -slab * 0.5, 0), stone)
	add_box(Vector3(half_x - ow, slab, footprint.y), Vector3((ow + half_x) * 0.5, -slab * 0.5, 0), stone)
	add_box(Vector3(opening_width, slab, half_z - z_front), Vector3(0, -slab * 0.5, (z_front + half_z) * 0.5), stone)
	add_box(Vector3(opening_width, slab, z_back + half_z), Vector3(0, -slab * 0.5, (z_back - half_z) * 0.5), stone)

	# Low curbs around the hole (not across the front, where the stairs start).
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.35, 0.55, opening_depth + 0.35), Vector3(sx * (ow + 0.175), 0.275, -0.175), pillar)
	add_box(Vector3(opening_width + 0.7, 0.55, 0.35), Vector3(0, 0.275, z_back - 0.175), pillar)

	# Pit walls and floor.
	var wall_h := pit_depth + 0.3
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.4, wall_h, opening_depth), Vector3(sx * (ow + 0.2), -wall_h * 0.5 - 0.0, 0), wall)
	add_box(Vector3(opening_width, wall_h, 0.4), Vector3(0, -wall_h * 0.5, z_back - 0.2), wall)
	add_box(Vector3(opening_width, wall_h, 0.4), Vector3(0, -wall_h * 0.5, z_front + 0.2), wall)
	add_box(Vector3(opening_width, 0.3, opening_depth), Vector3(0, -pit_depth - 0.15, 0), stone)
	# A dark passage in the back wall, into the unknown.
	add_box(Vector3(opening_width * 0.6, 2.0, 0.05), Vector3(0, -pit_depth + 1.0, z_back + 0.03), mat("void"), false)
	add_box(Vector3(opening_width * 0.6 + 0.3, 0.25, 0.1), Vector3(0, -pit_depth + 2.1, z_back + 0.05), pillar, false)

	# Stairs down: from the front edge to ~70% of the opening.
	var run := opening_depth * 0.7
	var depth_per := run / steps
	var rise_per := pit_depth / steps
	var mats := ["stone", "stone_pillar"]
	for i in steps - 1:
		var top := -(i + 1) * rise_per
		var h := pit_depth + top
		add_box(Vector3(opening_width, h, depth_per), Vector3(0, top - h * 0.5, z_front - (i + 0.5) * depth_per), mat(mats[i % 2]))

	# Archway at the top of the stairs.
	var pillar_x := ow + 0.45
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.9, arch_height, 0.9), Vector3(sx * pillar_x, arch_height * 0.5, z_front + 0.45), pillar)
		add_box(Vector3(1.1, 0.3, 1.1), Vector3(sx * pillar_x, 0.15, z_front + 0.45), wall, false)
		# Torch sconce: glowing bowl + flames (emission only, no light).
		var sconce := Vector3(sx * pillar_x, 2.5, z_front + 0.98)
		add_cylinder(0.14, 0.12, sconce, mat("iron"), false, Vector3.ZERO, null, 10, 0.2)
		add_cylinder(0.12, 0.04, sconce + Vector3(0, 0.06, 0), mat("glow_warm"), false)
		var flame := GPUParticles3D.new()
		flame.amount = 18
		flame.lifetime = 0.7
		flame.process_material = load("res://materials/fire_flame_process.tres")
		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.3)
		quad.material = load("res://materials/fire_particle.tres")
		flame.draw_pass_1 = quad
		flame.position = sconce + Vector3(0, 0.1, 0)
		add_generated(flame)
	var span := pillar_x * 2.0 + 0.9
	add_box(Vector3(span, 0.8, 1.0), Vector3(0, arch_height + 0.4, z_front + 0.45), pillar)
	add_box(Vector3(0.5, 0.6, 1.05), Vector3(0, arch_height + 0.5, z_front + 0.45), wall, false)
	# Stepped arch underside.
	add_box(Vector3(span - 1.8, 0.35, 0.9), Vector3(0, arch_height - 0.175, z_front + 0.45), wall, false)
	add_box(Vector3(span - 2.6, 0.25, 0.9), Vector3(0, arch_height - 0.47, z_front + 0.45), wall, false)
	add_label("DUNGEON", Vector3(0, arch_height + 0.4, z_front + 0.97), 64, Color(1.0, 0.8, 0.55))

	# Trigger at the bottom of the stairs (runtime only).
	if not Engine.is_editor_hint() and auto_enter:
		var trigger := Area3D.new()
		trigger.collision_layer = 0
		trigger.collision_mask = LAYER_WORLD
		trigger.monitorable = false
		var shape := BoxShape3D.new()
		shape.size = Vector3(opening_width, 2.0, opening_depth - run)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		trigger.add_child(collider)
		trigger.position = Vector3(0, -pit_depth + 1.0, z_back + (opening_depth - run) * 0.5)
		trigger.body_entered.connect(_on_trigger_body_entered)
		add_generated(trigger)


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
