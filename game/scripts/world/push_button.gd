class_name PushButton
extends Area3D
## A wall button a robot presses by bringing its core up against it, like
## the elevator buttons you have to grow to reach.

signal pressed

## How close (vertically) the core has to be to count as a press.
@export var reach_tolerance := 0.6
## Robots this close (on the floor plan) get a hint how to press it.
@export var hint_distance := 2.5

var is_pressed := false

@onready var _light: MeshInstance3D = $Light


func _ready() -> void:
	add_to_group(&"push_buttons")


## How `robot` could press this button ("" if it's pressed or far away).
## Jam players never worked out that you grow to reach buttons.
func get_hint(robot: RobotBody) -> String:
	var offset := global_position - robot.global_position
	if is_pressed or Vector2(offset.x, offset.z).length() > hint_distance:
		return ""
	var height := global_position.y - robot.get_core_position().y
	if height > reach_tolerance:
		return "Hold E to grow up to the button"
	if height < -reach_tolerance:
		return "Hold Q to shrink down to the button"
	return "Walk into the button to press it"


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
