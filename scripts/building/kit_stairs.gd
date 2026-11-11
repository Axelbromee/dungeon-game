@tool
class_name KitStairs
extends KitPiece
## Straight wooden stairs rising toward -Z. Origin at the bottom front edge
## (centre). Default: one storey (3 m) over two grid cells (4 m).
## An invisible ramp on the player_only layer makes walking up smooth; the
## steps themselves stay solid for everything else.

@export_range(2, 30) var steps: int = 12
@export var width: float = 2.0
@export var rise: float = 3.0
@export var run: float = 4.0
@export var side_boards: bool = true
@export var smooth_ramp: bool = true


func _build() -> void:
	var depth := run / steps
	var step_rise := rise / steps
	var mats := ["plank_a", "plank_b", "plank_c"]
	for i in steps:
		var h := (i + 1) * step_rise
		var z := -(i + 0.5) * depth
		# Body + a lighter tread with a little nosing.
		add_box(Vector3(width, h, depth), Vector3(0, h * 0.5, z), mat("wood_dark"))
		add_box(Vector3(width - 0.04, 0.04, depth + 0.03), Vector3(0, h - 0.02, z + 0.015), mat(mats[i % 3]), false)

	var angle := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	if side_boards:
		var wood := mat("wood")
		for side in [-1.0, 1.0]:
			add_box(Vector3(0.08, 0.3, length + 0.2),
				Vector3(side * (width * 0.5 + 0.04), rise * 0.5 + 0.12, -run * 0.5),
				wood, false, Vector3(rad_to_deg(angle), 0, 0))

	if smooth_ramp:
		var ramp := StaticBody3D.new()
		ramp.collision_layer = LAYER_PLAYER_ONLY
		ramp.collision_mask = 0
		add_generated(ramp)
		# Runs through the front-top corner of every step, starting one step
		# depth in front of the stairs at floor height.
		var t := 0.2
		var normal := Vector3(0, cos(angle), sin(angle))
		var mid := Vector3(0, rise * 0.5, depth - run * 0.5)
		add_collision_box(Vector3(width, t, length), mid - normal * t * 0.5, Vector3(rad_to_deg(angle), 0, 0), ramp)
