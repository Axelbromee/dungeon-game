@tool
class_name SpawnArea
extends Node3D
## Keeps up to `max_alive` enemies or forageables alive inside a box or
## circle. Each spawn picks a scene from `entries` by weight, finds the ground
## with a raycast (or the foot of a nearby wall for ore), and is placed only
## where it fits: no walls or objects in the way, `min_spacing` from the
## others, at least `min_player_distance` from the player and out of the
## player's sight. A spot that fails is retried every `retry_interval`.
##
## When a spawn leaves the scene (killed, harvested, mined) its slot frees up
## and is refilled `respawn_time` later. Spawned things become children of
## this node. Enemies that have set_leash() (the Slime) are leashed to the
## area's centre so they don't chase too far.
##
## Editor: the coloured outline (and the leash ring) is drawn only in the
## editor. Resize the area with Size / Radius in the Inspector.

signal spawned(node: Node3D)
## A spawn left the scene (killed, harvested...). Its slot refills later.
signal despawned(node: Node3D)

enum Shape { BOX, CIRCLE }
enum Placement {
	## On the ground, turned at random.
	GROUND,
	## On the ground at the foot of the nearest wall, facing out (ore veins).
	AGAINST_WALL,
}

@export_group("Area")
@export var shape: Shape = Shape.BOX
## Box size (X, Z) in metres, centred on this node.
@export var size: Vector2 = Vector2(16.0, 16.0)
## Circle radius in metres.
@export var radius: float = 8.0
## Outline colour in the editor (not shown in the game).
@export var editor_color: Color = Color(0.3, 0.9, 0.4)

@export_group("Spawning")
## What can spawn, each with a relative weight (90 / 10 = 90% / 10%).
@export var entries: Array[SpawnEntry] = []
@export_range(1, 100) var max_alive: int = 6
## Seconds after something is killed or harvested before its slot refills.
@export var respawn_time: float = 30.0
## Fill every slot when the level starts. Off: the slots fill one by one
## over the first `respawn_time` seconds.
@export var spawn_all_at_start: bool = true
## Off: nothing spawns (things already spawned stay).
@export var enabled: bool = true

@export_group("Placement")
@export var placement: Placement = Placement.GROUND
## Minimum distance between two spawns of this area.
@export var min_spacing: float = 2.5
## Turn each spawn to a random direction (GROUND placement).
@export var random_rotation: bool = true
## Render layers for everything spawned (0 = keep the scene's own). E.g.
## layer 2 inside floor 1's cave, which the sun doesn't light.
@export_flags_3d_render var render_layers: int = 0
## Free space a spawn needs (an upright capsule): no walls, bodies or other
## interactables may touch it.
@export var clearance_radius: float = 0.4
@export var clearance_height: float = 1.0
## Lift above the ground hit point.
@export var height_offset: float = 0.02
## The ground may be at most this far above this node's height. Keeps spawns
## off crates and wall tops; raise it on hilly ground.
@export var max_rise: float = 1.0
## ...and at most this far below it.
@export var max_drop: float = 6.0
@export_range(0.0, 89.0) var max_slope_degrees: float = 35.0
## AGAINST_WALL: how far from the random point to look for a wall.
@export var wall_search_distance: float = 3.0
## What counts as ground (and walls).
@export_flags_3d_physics var ground_mask: int = 1
## What a spawn must not overlap: world (1), interactables (3) and scenery (6:
## bushes and small rocks that only block spawns).
@export_flags_3d_physics var blocker_mask: int = 37
## Spots where the ground ray hits these layers first are skipped (layer 5:
## water surfaces, so moss by a lake never ends up under the water).
@export_flags_3d_physics var avoid_mask: int = 16
## Random spots tried per attempt before waiting `retry_interval`.
@export_range(1, 64) var tries_per_attempt: int = 12

@export_group("Player")
## Never spawn closer to the player than this.
@export var min_player_distance: float = 10.0
## Never spawn where the player's camera can see the spot.
@export var hide_from_player: bool = true
## Also apply the sight rule to the start-of-level fill. Off by default: the
## level is only just appearing, so nothing visibly pops in (the distance
## rule still applies).
@export var check_sight_at_start: bool = false
## Seconds before a blocked spawn tries again.
@export var retry_interval: float = 2.0
## What blocks the player's view (walls, ground).
@export_flags_3d_physics var sight_block_mask: int = 1

@export_group("Leash")
## Enemies chase at most this far from the area's centre, then hop back.
## 0 = no leash. Only for spawns with set_leash() (the Slime).
@export var leash_range: float = 15.0

var _alive: Array[Node3D] = []
## Times (seconds since start) at which a free slot tries to refill.
var _pending: Array[float] = []
var _time: float = 0.0
var _running: bool = false
var _player: Node3D
var _clearance_shape: CapsuleShape3D

var _outline: MeshInstance3D
var _label: Label3D
var _signature: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_outline()
		return
	_start.call_deferred()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if _make_signature() != _signature:
			_update_outline()
		return
	_time += delta
	if not _running or not enabled or _pending.is_empty():
		return
	# One attempt per frame, earliest slot first.
	var index := 0
	for i in _pending.size():
		if _pending[i] < _pending[index]:
			index = i
	if _pending[index] > _time:
		return
	if _alive.size() >= max_alive:
		_pending.remove_at(index)
	elif _try_spawn(hide_from_player):
		_pending.remove_at(index)
	else:
		_pending[index] = _time + retry_interval


## Things spawned by this area that are still alive.
func get_alive() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in _alive:
		if is_instance_valid(node):
			result.append(node)
	return result


func _start() -> void:
	# Let the level's collision shapes settle before raycasting.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_running = true
	for i in max_alive:
		if not enabled:
			_pending.append(_time)  # Fills (with all the rules) once enabled.
		elif spawn_all_at_start:
			if not _try_spawn(check_sight_at_start and hide_from_player):
				_pending.append(_time + retry_interval)
		else:
			_pending.append(_time + respawn_time * float(i + 1) / float(max_alive))


# --- Spawning ---------------------------------------------------------------

func _try_spawn(check_sight: bool) -> bool:
	var scene := _pick_scene()
	if scene == null:
		return false
	for _i in tries_per_attempt:
		var spot := _find_spot(check_sight)
		if not spot.is_empty():
			_spawn(scene, spot["xform"])
			return true
	return false


func _pick_scene() -> PackedScene:
	var total := 0.0
	for entry in entries:
		if entry != null and entry.scene != null and entry.weight > 0.0:
			total += entry.weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	var last: PackedScene = null
	for entry in entries:
		if entry == null or entry.scene == null or entry.weight <= 0.0:
			continue
		last = entry.scene
		roll -= entry.weight
		if roll <= 0.0:
			return entry.scene
	return last


func _spawn(scene: PackedScene, xform: Transform3D) -> void:
	var node := scene.instantiate() as Node3D
	if node == null:
		push_warning("SpawnArea %s: %s isn't a 3D scene" % [name, scene.resource_path])
		return
	# Placed before it enters the tree, so it never appears anywhere else.
	node.transform = global_transform.affine_inverse() * xform
	if render_layers != 0:
		for geometry in [node] + node.find_children("*", "GeometryInstance3D", true, false):
			if geometry is GeometryInstance3D:
				(geometry as GeometryInstance3D).layers = render_layers
	if leash_range > 0.0 and node.has_method("set_leash"):
		node.call("set_leash", global_position, leash_range)
	add_child(node)
	_alive.append(node)
	node.tree_exiting.connect(_on_spawn_exiting.bind(node), CONNECT_ONE_SHOT)
	spawned.emit(node)


func _on_spawn_exiting(node: Node3D) -> void:
	_alive.erase(node)
	if not is_inside_tree() or is_queued_for_deletion():
		return  # The whole level is going away.
	despawned.emit(node)
	_pending.append(_time + respawn_time)


# --- Finding a spot ---------------------------------------------------------

## {"xform": Transform3D} for a valid spot, or {} if this try failed.
func _find_spot(check_sight: bool) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var ground := _ground_at(space, global_transform * _random_local_point())
	if ground.is_empty():
		return {}
	var pos: Vector3 = ground["position"]
	# On a slope it sits a little lower, so the downhill side doesn't float
	# (applied after the checks below, which use the ground point).
	var up: Vector3 = ground["normal"]
	var sink := sqrt(maxf(1.0 - up.y * up.y, 0.0)) / maxf(up.y, 0.1) * clearance_radius * 0.6
	var facing := Vector3.ZERO
	if placement == Placement.AGAINST_WALL:
		var wall := _wall_near(space, pos)
		if wall.is_empty():
			return {}
		facing = wall["normal"]
		var at_wall: Vector3 = wall["position"]
		# Ground right at the foot of the wall.
		var foot := _ground_at(space, at_wall + facing * 0.3)
		if foot.is_empty():
			return {}
		pos = Vector3(at_wall.x, (foot["position"] as Vector3).y, at_wall.z)
		sink = 0.0
	if not _is_clear(space, pos, facing):
		return {}
	if _too_close_to_others(pos):
		return {}
	var player := _get_player()
	if player != null and player.global_position.distance_to(pos) < min_player_distance:
		return {}
	if check_sight and _player_can_see(space, pos):
		return {}

	var turn := Basis.IDENTITY
	if facing != Vector3.ZERO:
		turn = Basis.looking_at(-facing, Vector3.UP)  # Its +Z faces out of the wall.
	elif random_rotation:
		turn = Basis(Vector3.UP, randf() * TAU)
	return {"xform": Transform3D(turn, pos + Vector3.UP * (height_offset - sink))}


func _random_local_point() -> Vector3:
	if shape == Shape.CIRCLE:
		var r := radius * sqrt(randf())
		var angle := randf() * TAU
		return Vector3(cos(angle) * r, 0.0, sin(angle) * r)
	return Vector3(randf_range(-0.5, 0.5) * size.x, 0.0, randf_range(-0.5, 0.5) * size.y)


## Ground below `point` within max_rise / max_drop of this node's height.
func _ground_at(space: PhysicsDirectSpaceState3D, point: Vector3) -> Dictionary:
	var base_y := global_position.y
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, base_y + max_rise, point.z), Vector3(point.x, base_y - max_drop, point.z), ground_mask | avoid_mask)
	# A ray starting inside a wall reports it (normal 0), so it's rejected below.
	query.hit_from_inside = true
	query.exclude = _excluded_rids()
	var hit := space.intersect_ray(query)
	if hit.is_empty() or _is_moving_body(hit.collider) or _is_not_ground(hit.collider):
		return {}
	if (hit.normal as Vector3).y < cos(deg_to_rad(max_slope_degrees)):
		return {}
	return {"position": hit.position, "normal": hit.normal}


## Nearest wall around `pos`: {"position", "normal" (flat)} or {}.
func _wall_near(space: PhysicsDirectSpaceState3D, pos: Vector3) -> Dictionary:
	var origin := pos + Vector3.UP * 0.6
	var best := {}
	var best_distance := INF
	var start := randf() * TAU
	for i in 12:
		var angle := start + TAU * i / 12.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * wall_search_distance, ground_mask)
		query.exclude = _excluded_rids()
		var hit := space.intersect_ray(query)
		if hit.is_empty() or _is_moving_body(hit.collider) or _is_not_ground(hit.collider):
			continue
		var normal: Vector3 = hit.normal
		if absf(normal.y) > 0.5:
			continue  # A slope or ledge, not a wall.
		var distance := origin.distance_to(hit.position)
		if distance < best_distance:
			best_distance = distance
			normal.y = 0.0
			best = {"position": hit.position, "normal": normal.normalized()}
	return best


func _is_clear(space: PhysicsDirectSpaceState3D, pos: Vector3, facing: Vector3) -> bool:
	if _clearance_shape == null:
		_clearance_shape = CapsuleShape3D.new()
	_clearance_shape.radius = clearance_radius
	_clearance_shape.height = maxf(clearance_height, clearance_radius * 2.0)
	# Against a wall the capsule sits just in front of it.
	var centre := pos + Vector3.UP * (_clearance_shape.height * 0.5 + 0.08) + facing * (clearance_radius + 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance_shape
	query.transform = Transform3D(Basis.IDENTITY, centre)
	query.collision_mask = blocker_mask
	query.collide_with_areas = true
	return space.intersect_shape(query, 1).is_empty()


func _too_close_to_others(pos: Vector3) -> bool:
	for node in _alive:
		if not is_instance_valid(node):
			continue
		var offset := node.global_position - pos
		if Vector2(offset.x, offset.z).length() < min_spacing:
			return true
	return false


## True if the player's camera has a clear view of the spot.
func _player_can_see(space: PhysicsDirectSpaceState3D, pos: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var exclude: Array[RID] = []
	var player := _get_player()
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	for height in [0.3, maxf(clearance_height, 0.6)]:
		var point: Vector3 = pos + Vector3.UP * height
		if not camera.is_position_in_frustum(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, sight_block_mask)
		query.exclude = exclude
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _excluded_rids() -> Array[RID]:
	var rids: Array[RID] = []
	var player := _get_player()
	if player is CollisionObject3D:
		rids.append((player as CollisionObject3D).get_rid())
	for node in _alive:
		if is_instance_valid(node) and node is CollisionObject3D:
			rids.append((node as CollisionObject3D).get_rid())
	return rids


static func _is_moving_body(collider: Object) -> bool:
	return collider is CharacterBody3D or collider is RigidBody3D


## Water (avoid_mask) and colliders in the "no_spawn_ground" group (tree
## trunks, boulders) are never ground or walls to spawn against.
func _is_not_ground(collider: Object) -> bool:
	var body := collider as CollisionObject3D
	if body == null:
		return false
	return (body.collision_layer & avoid_mask) != 0 or body.is_in_group("no_spawn_ground")


func _get_player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player


# --- Editor outline ---------------------------------------------------------

func _make_signature() -> String:
	var parts := PackedStringArray([name])
	for property in get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			parts.append(str(get(property["name"])))
	for entry in entries:
		if entry != null:
			parts.append("%s:%s" % [entry.scene.resource_path if entry.scene else "", entry.weight])
	return "|".join(parts)


func _update_outline() -> void:
	_signature = _make_signature()
	if _outline == null:
		_outline = MeshInstance3D.new()
		_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_outline)  # No owner: never saved into the scene.
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.font_size = 40
		_label.pixel_size = 0.01
		_label.outline_size = 8
		add_child(_label)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var faint := Color(editor_color, 0.35)
	var ring := _outline_points()
	for i in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % ring.size()]
		_line(mesh, a, b, editor_color)  # Ground level.
		_line(mesh, a + Vector3.UP * max_rise, b + Vector3.UP * max_rise, faint)  # Top of the search.
	var step := 1 if shape == Shape.BOX else maxi(ring.size() >> 3, 1)
	for i in range(0, ring.size(), step):
		_line(mesh, ring[i], ring[i] + Vector3.UP * max_rise, faint)
	if leash_range > 0.0:
		var leash_color := Color(1.0, 0.45, 0.3, 0.45)
		var segments := 48
		for i in segments:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			_line(mesh, Vector3(cos(a0), 0.0, sin(a0)) * leash_range, Vector3(cos(a1), 0.0, sin(a1)) * leash_range, leash_color)
	mesh.surface_end()
	_outline.mesh = mesh

	_label.position = Vector3.UP * (max_rise + 0.6)
	_label.modulate = editor_color
	_label.text = "%s\n%s\nmax %d · %ss" % [name, _entries_summary(), max_alive, respawn_time]


func _outline_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if shape == Shape.CIRCLE:
		for i in 48:
			var angle := TAU * i / 48.0
			points.append(Vector3(cos(angle), 0.0, sin(angle)) * radius)
	else:
		var hx := size.x * 0.5
		var hz := size.y * 0.5
		points.assign([Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)])
	return points


func _entries_summary() -> String:
	var total := 0.0
	for entry in entries:
		if entry != null and entry.scene != null:
			total += maxf(entry.weight, 0.0)
	if total <= 0.0:
		return "(nothing to spawn)"
	var parts := PackedStringArray()
	for entry in entries:
		if entry != null and entry.scene != null:
			parts.append("%s %d%%" % [entry.scene.resource_path.get_file().get_basename(), roundi(entry.weight / total * 100.0)])
	return ", ".join(parts)


static func _line(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(b)
