class_name PlayerCamera
extends Node3D
## Third-person orbit camera that follows the robot's core. Pulls back as
## the robot grows so tall climbs stay readable.

@export var mouse_sensitivity := 0.0025
@export var min_pitch := deg_to_rad(-70.0)
@export var max_pitch := deg_to_rad(35.0)
@export var base_distance := 4.5
## Extra distance per meter of torso extension.
@export var distance_per_extension := 0.5
@export var follow_smoothing := 14.0

var yaw := 0.0
var pitch := deg_to_rad(-15.0)
var target: RobotBody

@onready var _pivot: Node3D = $Pivot
@onready var _arm: SpringArm3D = $Pivot/SpringArm


func _ready() -> void:
	top_level = true
	if target:
		yaw = target.rotation.y
		global_position = target.get_core_position()
		_arm.add_excluded_object(target.get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * mouse_sensitivity
		pitch = clampf(pitch - motion.relative.y * mouse_sensitivity, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	if not target:
		return
	var weight := 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(target.get_core_position(), weight)
	rotation = Vector3(0.0, yaw, 0.0)
	_pivot.rotation.x = pitch
	_arm.spring_length = base_distance + target.extension * distance_per_extension
