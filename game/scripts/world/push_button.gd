class_name PushButton
extends Area3D
## A wall button a robot presses by bringing its core up against it, like
## the elevator buttons you have to grow to reach.

signal pressed

## How close (vertically) the core has to be to count as a press.
@export var reach_tolerance := 0.6

var is_pressed := false

@onready var _light: MeshInstance3D = $Light


func _physics_process(_delta: float) -> void:
	if is_pressed:
		return
	for body in get_overlapping_bodies():
		if body is RobotBody \
				and absf(body.get_core_position().y - global_position.y) < reach_tolerance:
			_press()
			return


func _press() -> void:
	is_pressed = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 1.0, 0.4)
	material.emission_enabled = true
	material.emission = Color(0.3, 1.0, 0.4)
	_light.material_override = material
	pressed.emit()
