@tool
class_name KitStairs
extends KitPiece
## Straight wooden stairs rising toward -Z: the KayKit wooden stairs scaled
## evenly so they climb `rise` (4 m = one storey: 3.26 m wide, 5.93 m long).
## Origin at the bottom front edge (centre).
## An invisible ramp on the player_only layer makes walking up smooth; the
## step colliders stay solid for everything else.

## Number of step colliders (the model has its own steps).
@export_range(2, 30) var steps: int = 16
## Not used: width follows the rise (kept so existing scenes load).
@export var width: float = 3.26
@export var rise: float = 4.0
## Not used: run follows the rise (kept so existing scenes load).
@export var run: float = 5.93
## Not used by the KayKit stairs (kept so existing scenes load unchanged).
@export var side_boards: bool = true
@export var smooth_ramp: bool = true

## stairs_wood: 3.3 wide, 4.05 tall, 6 long; high end at model z = 0.
const MODEL_SIZE := Vector3(3.3, 4.05, 6.0)


## Real footprint at the current rise: (width, run).
func footprint() -> Vector2:
	var s := rise / MODEL_SIZE.y
	return Vector2(MODEL_SIZE.x * s, MODEL_SIZE.z * s)


func _build() -> void:
	var s := rise / MODEL_SIZE.y
	var w := MODEL_SIZE.x * s
	var length := MODEL_SIZE.z * s
	# Model z 0 (top) -> -length, model z 6 (bottom front) -> 0.
	add_model_xform(kk("stairs_wood"), Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(0, 0, -length)))
	var depth := length / steps
	var step_rise := rise / steps
	for i in steps:
		var h := (i + 1) * step_rise
		add_collision_box(Vector3(w, h, depth), Vector3(0, h * 0.5, -(i + 0.5) * depth))

	if smooth_ramp:
		var angle := atan2(rise, length)
		var ramp_length := sqrt(length * length + rise * rise)
		var ramp := StaticBody3D.new()
		ramp.collision_layer = LAYER_PLAYER_ONLY
		ramp.collision_mask = 0
		add_generated(ramp)
		# Runs through the front-top corner of every step, starting one step
		# depth in front of the stairs at floor height.
		var t := 0.2
		var normal := Vector3(0, cos(angle), sin(angle))
		var mid := Vector3(0, rise * 0.5, depth - length * 0.5)
		add_collision_box(Vector3(w, t, ramp_length), mid - normal * t * 0.5, Vector3(rad_to_deg(angle), 0, 0), ramp)
