@tool
class_name Waterfall
extends Node3D
## A waterfall in the low-poly KayKit style: a thick column of water built
## from stacked, overlapping rounded chunks (round at the front, flat against
## the cliff at the back), with thinner strands over it, each flowing at its
## own speed in its own shades. Coloured by shaders/world/waterfall.gdshader:
## moving noise in lighter water bands and foam, with foam and gaps towards
## the edges. It runs over a rounded lip at the cliff top,
## follows the cliff face down and widens a little towards the bottom. Where it
## lands: white foam on the water, churning foam, splashing drops and mist.
## Rebuilds live in the editor when a setting changes; the built nodes aren't
## saved.
##
## The origin is the foot of the cliff face, on the pool's surface; the water
## faces +Z (away from the cliff, which is towards -Z). **Snap To Cliff** finds
## the cliff behind it (raycasts) and fits the water to its face; until then it
## falls down a straight, vertical face `height` tall.

const WATERFALL_SHADER := preload("res://shaders/world/waterfall.gdshader")
const FOAM_SHADER := preload("res://shaders/world/water_foam.gdshader")
## The waterfall shader's "pixels" per metre (keeps its pattern the same size
## whatever the size of the water).
const PIXELS_PER_METRE := 10.0
## How wide the top is, as a share of the bottom's width (a little narrower).
const TOP_WIDTH := 0.8
## Sides of the water's rounded cross-section (low-poly).
const SIDES := 10
## The flat run on top before the lip, and how far below the pool's surface
## the water goes in.
const RUN := 1.5
const SINK := 0.5
## The main body's chunks: their length along the water and how much each
## overlaps the next.
const CHUNK := 2.4
const CHUNK_OVERLAP := 0.7
## Overlapping strands over the main body: [across (share of the width),
## width (share), thickness (share), how far in front (share of the
## thickness), speed (x flow speed), water colour at the top, at the bottom].
const STRANDS := [
	[-0.28, 0.42, 0.5, 0.42, 1.25, Color(0.36, 0.67, 0.73), Color(0.3, 0.58, 0.63)],
	[0.06, 0.36, 0.45, 0.5, 0.8, Color(0.31, 0.62, 0.68), Color(0.26, 0.53, 0.59)],
	[0.3, 0.4, 0.5, 0.4, 1.45, Color(0.38, 0.7, 0.76), Color(0.32, 0.6, 0.66)],
]
## The main body's water colour at the top and the bottom.
const BODY_COLORS := [Color(0.333, 0.643, 0.702), Color(0.287, 0.553, 0.605)]
## Snap To Cliff: how far behind the waterfall it looks for the cliff, in metres.
const SNAP_REACH := 90.0

## Height of the fall (metres): from the pool's surface to the cliff top
## (set by Snap To Cliff).
@export_range(1.0, 100.0, 0.1) var height: float = 12.0:
	set(value):
		height = value
		_rebuild()
## Width at the bottom (metres); the top is a little narrower.
@export_range(0.5, 40.0, 0.1) var width: float = 5.0:
	set(value):
		width = value
		_rebuild()
## How deep the column of water is, front to back (metres).
@export_range(0.5, 6.0, 0.05) var thickness: float = 2.0:
	set(value):
		thickness = value
		_rebuild()
## How fast the water scrolls down (metres per second); the strands run a
## little faster or slower than this.
@export_range(0.0, 20.0, 0.1) var flow_speed: float = 4.0:
	set(value):
		flow_speed = value
		_rebuild()
## Finds the cliff behind the waterfall and fits the water to it: the top on
## the cliff top, the back flush against the face down to the pool.
@export_tool_button("Snap To Cliff") var snap_to_cliff_action := snap_to_cliff

## The cliff face the water runs down, as measured by Snap To Cliff: points
## (local Z, Y) from the foot (0, 0) up to the top edge. Empty = a straight,
## vertical face `height` tall.
@export_storage var cliff_profile := PackedVector2Array():
	set(value):
		cliff_profile = value
		_rebuild()

var _built: Array[Node] = []
## Seamless noise the waterfall shader moves (made once per build, shared by
## the body and strands).
var _noise_texture: NoiseTexture2D


func _ready() -> void:
	_rebuild()


## Raycasts down behind the waterfall (every half metre, up to SNAP_REACH) to
## find the ground's profile: the cliff foot (where the ground first climbs
## above the pool) and its top edge (where it levels out at the top). Moves
## the waterfall to the foot and fits the water to the face between them.
func snap_to_cliff() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var back := -forward
	var origin := global_position
	var samples: Array[Vector2] = []  # (metres behind the origin, ground height)
	var behind := -8.0
	while behind <= SNAP_REACH:
		var at := origin + back * behind
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 300.0, at + Vector3.DOWN * 100.0)
		var hit := space.intersect_ray(query)
		# The map's invisible border walls are not the cliff: stop there.
		if hit.is_empty() or (hit.collider as Node).name == &"Bounds":
			break
		samples.append(Vector2(behind, (hit.position as Vector3).y))
		behind += 0.5
	# The foot: the first spot that rises above the water and keeps climbing
	# into a real cliff (at least 5 m higher within the next 15 m).
	var foot := -1
	for i in samples.size():
		if samples[i].y < origin.y + 0.4:
			continue
		var climbs := false
		for j in range(i, mini(i + 30, samples.size())):
			if samples[j].y > origin.y + 5.0:
				climbs = true
				break
		if climbs:
			foot = i
			break
	if foot < 0:
		push_warning("Waterfall: no cliff found behind %s" % name)
		return
	# The top edge: where the ground first gets within 1 m of its highest point.
	var top_height := -INF
	for i in range(foot, samples.size()):
		top_height = maxf(top_height, samples[i].y)
	var top := foot
	while top < samples.size() - 1 and samples[top].y < top_height - 1.0:
		top += 1
	# The face, slightly smoothed (the cliff's steps and rocks are bumpy), in
	# local space with the foot at (0, 0).
	var profile := PackedVector2Array()
	for i in range(foot, top + 1, 2):
		var sum := 0.0
		var count := 0
		for j in range(maxi(i - 2, foot), mini(i + 3, top + 1)):
			sum += samples[j].y
			count += 1
		profile.append(Vector2(-(samples[i].x - samples[foot].x), sum / count - origin.y))
	var top_point := Vector2(-(samples[top].x - samples[foot].x), samples[top].y - origin.y)
	if profile[profile.size() - 1] != top_point:
		profile.append(top_point)
	profile[0] = Vector2.ZERO
	global_position = origin + back * samples[foot].x
	height = top_point.y
	cliff_profile = profile


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for node in _built:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_built.clear()
	_noise_texture = NoiseTexture2D.new()
	_noise_texture.width = 256
	_noise_texture.height = 256
	_noise_texture.seamless = true
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	_noise_texture.noise = noise
	var path := _path(thickness)
	_add(_chunks(path))
	for i in STRANDS.size():
		var s: Array = STRANDS[i]
		_add(_strand("Strand%d" % i, _path(thickness * float(s[2])), s[0], s[1], s[2], s[3], s[4], s[5], s[6], i + 1))
	var bottom: Vector2 = path[path.size() - 1][0]
	var landing := Vector3(0.0, 0.0, bottom.x)
	_add(_foam_ring(landing))
	_add(_churn(landing))
	_add(_splash(landing))
	_add(_mist(landing))


func _add(node: Node) -> void:
	add_child(node)  # No owner: never saved into the scene.
	_built.append(node)


# --- The water's path --------------------------------------------------------

## The cliff face from the foot up to the top edge (local Z, Y).
func _face() -> PackedVector2Array:
	if cliff_profile.size() >= 2:
		return cliff_profile
	return PackedVector2Array([Vector2.ZERO, Vector2(0.0, height)])


## The centre line of a body of water `depth` deep, top to bottom, every half
## metre: [Vector2(z, y), how far down it is (0 = top, 1 = pool)]. A flat run
## on the cliff top, a rounded lip over the edge, then down the face (its
## back on the face), and on into the pool.
func _path(depth: float) -> Array:
	var face := _face()
	var top: Vector2 = face[face.size() - 1]
	var half := depth * 0.5
	# Outward normals of the face (towards the open side), foot to top.
	var normals: Array[Vector2] = []
	for i in face.size():
		var a: Vector2 = face[maxi(i - 1, 0)]
		var b: Vector2 = face[mini(i + 1, face.size() - 1)]
		var up := (b - a).normalized()  # Up the face (towards -Z near the top).
		normals.append(Vector2(up.y, -up.x))  # Turned: out of the cliff.
	var line: Array[Vector2] = []
	# Flat run on top, then the lip: the normal turning from straight up
	# (+Y, angle 90 degrees) to the face's own, around the top edge.
	line.append(top + Vector2(-RUN, half))
	var lip_to: float = normals[normals.size() - 2].angle()
	for k in 7:
		line.append(top + Vector2.from_angle(lerp_angle(PI * 0.5, lip_to, k / 6.0)) * half)
	# Down the face, its back on it.
	for i in range(face.size() - 2, -1, -1):
		line.append(face[i] + normals[i] * half)
	# On down into the pool.
	var last: Vector2 = line[line.size() - 1]
	line.append(Vector2(last.x, -SINK))
	# Every half metre along it, with how far down each point is.
	var points: Array = []
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var steps := maxi(ceili(a.distance_to(b) / 0.5), 1)
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			points.append([p, clampf(1.0 - p.y / maxf(top.y, 0.001), 0.0, 1.0)])
	points.append([line[line.size() - 1], 1.0])
	return points


## Out of the water's front face at path point `i`: up on the run on top,
## out of the cliff on the face.
func _front(path: Array, i: int) -> Vector3:
	var prev: Vector2 = path[maxi(i - 1, 0)][0]
	var next: Vector2 = path[mini(i + 1, path.size() - 1)][0]
	var down := (next - prev).normalized()  # Along the flow, as (z, y).
	return Vector3(0.0, down.x, -down.y)


# --- The water ---------------------------------------------------------------

## The main body: chunks of rounded, low-poly water stacked down the path,
## each overlapping the next and a little different in size, so it reads as
## a solid, lumpy column from every side.
func _chunks(path: Array) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var per_chunk := maxi(roundi(CHUNK / 0.5), 2)
	var step := maxi(roundi((CHUNK - CHUNK_OVERLAP) / 0.5), 1)
	var start := 0
	while start < path.size() - 1:
		var stop := mini(start + per_chunk, path.size() - 1)
		var swell := rng.randf_range(1.0, 1.1)
		var rings: Array = []
		for i in range(start, stop + 1):
			# Rounded ends: each chunk tapers a little at both ends.
			var t := float(i - start) / maxf(stop - start, 1)
			var round_end := lerpf(0.8, 1.0, sin(t * PI))
			rings.append(_ring(path, i, 0.0, 1.0, 1.0, 0.0, swell * round_end, rng))
		_tube(st, rings, Color.WHITE)
		start += step
	st.generate_normals()  # Corners aren't shared, so every face stays flat.
	return _water_instance("Body", st.commit(), BODY_COLORS[0], BODY_COLORS[1], 1.0, 0, path)


## A strand: a thinner, continuous body over the front of the main one.
func _strand(strand_name: String, path: Array, across: float, share_width: float, share_depth: float,
		ahead: float, speed: float, light: Color, dark: Color, order: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + order
	var rings: Array = []
	for i in path.size():
		var v: float = path[i][1]
		# Strands sway a little from side to side as they fall.
		var sway := sin(v * TAU * 1.2 + order * 1.7) * 0.05 * v
		rings.append(_ring(path, i, across + sway, share_width, share_depth, ahead, 1.0, rng))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, rings, Color.WHITE)
	st.generate_normals()
	return _water_instance(strand_name, st.commit(), light, dark, speed, order, path)


## One ring of a cross-section at path point `i`: round at the front, its
## back flat on the cliff face (so it sits flush), low-poly lumps on the
## front only. UV: 0..1 across (its sides at 0 and 1) and 0..1 from the top
## to the bottom, for the waterfall shader. Returns [[point, uv], ...].
func _ring(path: Array, i: int, across: float, share_width: float, share_depth: float, ahead: float,
		swell: float, rng: RandomNumberGenerator) -> Array:
	var at: Vector2 = path[i][0]
	var v: float = path[i][1]
	var front := _front(path, i)
	var half := width * 0.5 * share_width * lerpf(TOP_WIDTH, 1.0, v) * swell
	var depth := thickness * share_depth
	var centre := Vector3(across * width * lerpf(TOP_WIDTH, 1.0, v), at.y, at.x) + front * thickness * ahead
	var ring := []
	for k in SIDES:
		var a := TAU * k / SIDES
		var out := sin(a)
		var lump := rng.randf_range(0.9, 1.12) if out > 0.0 else 1.0
		# Front: a round bulge; back: half the depth back, onto the face.
		var reach := out * depth * 0.5 * (lump * swell if out > 0.0 else 1.0)
		var point := centre + Vector3.RIGHT * cos(a) * half * lump + front * reach
		ring.append([point, Vector2((cos(a) + 1.0) * 0.5, float(i) / maxf(path.size() - 1, 1))])
	return ring


## Joins rings into a closed tube (flat-shaded, both ends capped).
func _tube(st: SurfaceTool, rings: Array, flow: Color) -> void:
	for i in rings.size() - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			var a: Array = rings[i][k]
			var b: Array = rings[i][k2]
			var c: Array = rings[i + 1][k]
			var d: Array = rings[i + 1][k2]
			for tri in [[a, b, c], [b, d, c]]:
				for corner: Array in tri:
					st.set_color(flow)
					st.set_uv(corner[1])
					st.add_vertex(corner[0])
	for end: Array in [rings[0], rings[rings.size() - 1]]:
		var middle := Vector3.ZERO
		for corner: Array in end:
			middle += corner[0]
		middle /= SIDES
		for k in SIDES:
			for corner: Array in [[middle, Vector2.ZERO], end[k], end[(k + 1) % SIDES]]:
				st.set_color(flow)
				st.set_uv(corner[1])
				st.add_vertex(corner[0])


## A body of water with its own waterfall material: colours from `light` (top)
## to `dark` (bottom), moving at `speed` x the flow speed, the pattern sized to
## its real width and length (`path`).
func _water_instance(instance_name: String, mesh: ArrayMesh, light: Color, dark: Color, speed: float,
		order: int, path: Array) -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([light, dark])
	var colors := GradientTexture1D.new()
	colors.gradient = gradient
	var length := maxf((path.size() - 1) * 0.5, 1.0)
	var material := ShaderMaterial.new()
	material.shader = WATERFALL_SHADER
	material.render_priority = order  # Strands draw over the body.
	material.set_shader_parameter("noise_texture", _noise_texture)
	material.set_shader_parameter("water_gradient", colors)
	material.set_shader_parameter("sprite_or_color_rect_resolution", Vector2(width, length) * PIXELS_PER_METRE)
	material.set_shader_parameter("waterfall_speed", flow_speed * speed * PIXELS_PER_METRE)
	material.set_shader_parameter("waterfall_noise_blend_speed", flow_speed * speed * PIXELS_PER_METRE * 0.06)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = instance_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


# --- Where it lands ----------------------------------------------------------

## White foam rings spreading on the water around the impact.
func _foam_ring(landing: Vector3) -> MeshInstance3D:
	var radius := width * 0.9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 20
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		for v: Vector2 in [Vector2.ZERO, Vector2(cos(a1), sin(a1)), Vector2(cos(a0), sin(a0))]:
			st.set_normal(Vector3.UP)
			st.set_uv(v * 0.5 + Vector2(0.5, 0.5))
			st.add_vertex(Vector3(v.x, 0.0, v.y) * radius)
	var material := ShaderMaterial.new()
	material.shader = FOAM_SHADER
	var foam := MeshInstance3D.new()
	foam.name = "FoamRing"
	foam.mesh = st.commit()
	foam.material_override = material
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.position = landing + Vector3(0.0, 0.04, thickness * 0.3)
	return foam


## Thick churning foam: low-poly white lumps welling up, swelling and fading
## all along the impact.
func _churn(landing: Vector3) -> CPUParticles3D:
	var churn := _particles("Churn", 64, 1.8, _blob_mesh(1.0))
	churn.emission_box_extents = Vector3(width * 0.6, 0.05, thickness * 0.5 + 0.7)
	churn.direction = Vector3.UP
	churn.spread = 70.0
	churn.initial_velocity_min = 0.4
	churn.initial_velocity_max = 1.1
	churn.gravity = Vector3.ZERO
	churn.damping_min = 0.5
	churn.damping_max = 1.0
	churn.scale_amount_min = 0.8
	churn.scale_amount_max = 1.7
	churn.scale_amount_curve = _curve([Vector2(0.0, 0.3), Vector2(0.35, 1.0), Vector2(1.0, 0.75)])
	churn.color_ramp = _fade(Color(0.97, 0.99, 1.0), [0.0, 0.95, 0.85, 0.0])
	churn.position = landing + Vector3(0.0, 0.1, thickness * 0.5 + 0.4)
	return churn


## Splashing drops thrown up and out where the water hits.
func _splash(landing: Vector3) -> CPUParticles3D:
	var splash := _particles("Splash", 70, 1.0, _blob_mesh(0.25))
	splash.emission_box_extents = Vector3(width * 0.5, 0.1, thickness * 0.5 + 0.2)
	splash.direction = Vector3(0.0, 1.0, 0.35)
	splash.spread = 50.0
	splash.initial_velocity_min = 3.0
	splash.initial_velocity_max = 6.5
	splash.scale_amount_min = 0.6
	splash.scale_amount_max = 1.5
	splash.color_ramp = _fade(Color(0.95, 0.98, 1.0), [0.95, 0.9, 0.0])
	splash.position = landing + Vector3(0.0, 0.1, thickness * 0.5 + 0.3)
	return splash


## Light mist rising slowly from the impact: soft, pale puffs.
func _mist(landing: Vector3) -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * maxf(width * 0.8, 3.0)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	quad.material = material
	var mist := _particles("Mist", 30, 3.5, quad, false)
	mist.emission_box_extents = Vector3(width * 0.6, 0.3, thickness * 0.6 + 0.5)
	mist.direction = Vector3(0.0, 1.0, 0.3)
	mist.spread = 25.0
	mist.initial_velocity_min = 0.6
	mist.initial_velocity_max = 1.4
	mist.gravity = Vector3.ZERO
	mist.damping_min = 0.1
	mist.damping_max = 0.3
	mist.angle_min = 0.0
	mist.angle_max = 360.0
	mist.scale_amount_min = 0.8
	mist.scale_amount_max = 1.5
	mist.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(1.0, 1.6)])
	mist.color_ramp = _fade(Color(0.95, 0.98, 1.0), [0.0, 0.38, 0.24, 0.0])
	mist.position = landing + Vector3(0.0, 0.6, thickness * 0.5 + 0.5)
	return mist


## Particles with the shared settings: always on, preprocessed so they're
## already going when the scene appears, no shadows. Lit by default (the foam
## catches the light like the KayKit models, with a soft glow to stay white).
func _particles(node_name: String, amount: int, lifetime: float, mesh: Mesh, lit: bool = true) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.mesh = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lit and mesh.surface_get_material(0) == null and mesh is PrimitiveMesh:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		# A soft white glow, so the foam stays white even in the cliff's shade.
		material.emission_enabled = true
		material.emission = Color(0.85, 0.9, 0.95)
		material.emission_energy_multiplier = 0.55
		(mesh as PrimitiveMesh).material = material
	return particles


## A low-poly lump of foam (few faces, so it's faceted like the KayKit models).
func _blob_mesh(radius: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.6
	sphere.radial_segments = 6
	sphere.rings = 3
	return sphere


static func _curve(points: Array) -> Curve:
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	return curve


## A colour fading in / out over the particle's life (one alpha per stop).
static func _fade(color: Color, alphas: Array) -> Gradient:
	var gradient := Gradient.new()
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for i in alphas.size():
		colors.append(Color(color, alphas[i]))
		offsets.append(float(i) / (alphas.size() - 1))
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient
