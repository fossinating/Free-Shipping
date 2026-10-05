class_name LaunchRamp
extends Area3D
## The lip of a ramp. A robot on wheels that rolls over it fast enough is
## launched along the area's -Z axis. Treads just roll off the end.

## Horizontal and upward launch speed, in m/s.
@export var launch_speed := 12.0
@export var launch_up := 10.0
## How fast a robot has to be going up the ramp to take off.
@export var min_speed := 4.0


func _ready() -> void:
	monitorable = false


func get_forward() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _physics_process(_delta: float) -> void:
	var forward := get_forward()
	for body in get_overlapping_bodies():
		var robot := body as RobotBody
		if robot == null or not robot.wheels or robot.is_launched:
			continue
		if Vector3(robot.velocity.x, 0.0, robot.velocity.z).dot(forward) >= min_speed:
			robot.launch(forward * launch_speed + Vector3.UP * launch_up)
