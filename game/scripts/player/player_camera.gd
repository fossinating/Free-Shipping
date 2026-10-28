class_name PlayerCamera
extends Node3D
## Third-person orbit camera that follows the robot's core. Pulls back as
## the robot grows so tall climbs stay readable.

@export var min_pitch := deg_to_rad(-70.0)
@export var max_pitch := deg_to_rad(35.0)
@export var base_distance := 4.5
## Extra distance per meter of torso extension.
@export var distance_per_extension := 0.5
@export var follow_smoothing := 14.0
@export_group("Aiming")
## While aiming a throw, the view shifts this far right and up so the arc
## isn't hidden behind the robot...
@export var aim_offset := Vector2(0.9, 0.35)
## ...and moves in to this fraction of the usual distance.
@export var aim_distance_scale := 0.6
@export var aim_smoothing := 10.0

## Set by the controller while a throw is being aimed.
var aiming := false

var yaw := 0.0
var pitch := deg_to_rad(-15.0)
var target: RobotBody
# 0 normally, 1 fully over the shoulder.
var _aim := 0.0

@onready var _pivot: Node3D = $Pivot
@onready var _arm: SpringArm3D = $Pivot/SpringArm
@onready var _camera: Camera3D = $Pivot/SpringArm/Camera


func _ready() -> void:
	Settings.load_once()
	top_level = true
	if target:
		yaw = target.rotation.y
		global_position = target.get_core_position()
		_arm.add_excluded_object(target.get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * Settings.mouse_sensitivity
		pitch = clampf(pitch - motion.relative.y * Settings.mouse_sensitivity, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	if not target:
		return
	var weight := 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(target.get_core_position(), weight)
	rotation = Vector3(0.0, yaw, 0.0)
	_pivot.rotation.x = pitch
	_aim = lerpf(_aim, 1.0 if aiming else 0.0, 1.0 - exp(-aim_smoothing * delta))
	# Shifting the view rather than the arm keeps the arm's collision honest
	# next to walls.
	_camera.h_offset = aim_offset.x * _aim
	_camera.v_offset = aim_offset.y * _aim
	_arm.spring_length = (base_distance + target.extension * distance_per_extension) \
		* lerpf(1.0, aim_distance_scale, _aim)
