class_name TargetDummy
extends StaticBody3D
## Indestructible training dummy. Shows last hit and running totals.

@export var idle_text: String = "DUMMY"
## Seconds after the last hit before the label goes back to idle.
@export var label_hold_time: float = 3.0

var hits: int = 0
var total_damage: float = 0.0

var _idle_timer: float = 0.0

@onready var _label: Label3D = $Label3D


func _ready() -> void:
	_label.text = idle_text


func take_damage(amount: float) -> void:
	hits += 1
	total_damage += amount
	HitFlash.flash(self)
	_label.text = "-%d\nhits %d | total %d" % [roundi(amount), hits, roundi(total_damage)]
	_label.modulate = Color(1.0, 0.7, 0.3)
	_idle_timer = label_hold_time

	var tween := create_tween()
	_label.scale = Vector3.ONE * 1.4
	tween.tween_property(_label, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	if _idle_timer > 0.0:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_label.text = idle_text
			_label.modulate = Color(1, 1, 1, 0.6)
