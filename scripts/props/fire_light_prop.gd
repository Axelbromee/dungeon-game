@tool
class_name FireLightProp
extends Node3D
## Root of the torch and brazier props. Puts the fire light's settings on the
## root so each placed copy can be tuned in the Inspector, without turning on
## "Editable Children". Drives the child OmniLight3D named "Light" (a
## FlickerLight). Values are applied when the prop enters the scene, before
## the flicker starts, so change them in the editor rather than from code.

@export var light_enabled: bool = true:
	set(value):
		light_enabled = value
		_apply()
@export var light_energy: float = 3.0:
	set(value):
		light_energy = value
		_apply()
@export var light_range: float = 13.0:
	set(value):
		light_range = value
		_apply()
@export var light_color: Color = Color(1.0, 0.55, 0.22):
	set(value):
		light_color = value
		_apply()
@export_range(0.0, 1.0) var flicker_amount: float = 0.25:
	set(value):
		flicker_amount = value
		_apply()


func _enter_tree() -> void:
	_apply()


func _apply() -> void:
	var light := get_node_or_null("Light") as OmniLight3D
	if light == null:
		return  # Not built yet (properties are set before children exist).
	light.visible = light_enabled
	light.light_energy = light_energy
	light.omni_range = light_range
	light.light_color = light_color
	light.set("flicker_amount", flicker_amount)
