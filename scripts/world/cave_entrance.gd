@tool
class_name CaveEntrance
extends KitPiece
## Wooden mine entrance: two thick posts and a beam across the top, each made
## of KayKit logs (Wood_Log_B) laid end to end at one uniform scale, with box
## collision. Rebuilds live in the editor when a setting changes.
##
## The origin is on the ground in the middle of the opening; the frame spans
## X (width) and faces +Z. The posts stand just outside `width` and sink a
## little into the ground.

const LOG := "res://KayKit/Assets3/gltf/Wood_Log_B.gltf"
## How far the posts go into the ground, and how far the beam reaches past
## the posts on each side.
const POST_SINK := 0.3
const BEAM_OVERHANG := 0.35

## Clear width between the posts (metres).
@export_range(1.0, 30.0, 0.1) var width: float = 9.0
## Clear height under the beam (metres).
@export_range(1.0, 20.0, 0.1) var height: float = 5.0
## Thickness of the posts and the beam (metres); sets the logs' uniform scale.
@export_range(0.3, 2.0, 0.05) var beam_thickness: float = 0.9


func _build() -> void:
	var box := model_aabb(LOG)
	var s := beam_thickness / maxf(maxf(box.size.x, box.size.y), 0.001)
	var piece := box.size.z * s  # One log's length.
	var t := beam_thickness
	# Same look on every rebuild: each log is rolled a little differently.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Posts: logs standing upright, end to end, from just below the ground
	# into the beam.
	var bottom := -POST_SINK
	var top := height + t * 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * (width + t) * 0.5
		var post_count := maxi(ceili((top - bottom) / piece), 1)
		var post_step := (top - bottom - piece) / maxf(post_count - 1, 1)
		for k in post_count:
			var turn := (Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * s)
			var centre := Vector3(x, bottom + piece * 0.5 + post_step * k, 0.0)
			add_model_xform(LOG, Transform3D(turn, centre - turn * box.get_center()))
		add_collision_box(Vector3(t * 0.9, top - bottom, t * 0.9), Vector3(x, (top + bottom) * 0.5, 0.0))

	# Beam: logs lying along X across the top of the posts.
	var span := width + t * 2.0 + BEAM_OVERHANG * 2.0
	var count := maxi(ceili(span / piece), 1)
	var step := (span - piece) / maxf(count - 1, 1)
	var beam_y := height + t * 0.5
	for k in count:
		var turn := (Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, rng.randf() * TAU)).scaled(Vector3.ONE * s)
		var centre := Vector3(-span * 0.5 + piece * 0.5 + step * k, beam_y, 0.0)
		add_model_xform(LOG, Transform3D(turn, centre - turn * box.get_center()))
	add_collision_box(Vector3(span, t * 0.9, t * 0.9), Vector3(0.0, beam_y, 0.0))
