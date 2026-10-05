class_name Conveyor
extends Area3D
## A conveyor belt. Robots and packages on it ride along the area's -Z
## axis. Robots with the wheel base ride it much faster (see RobotBody).

## Belt speed, in m/s.
@export var speed := 2.5


func _ready() -> void:
	add_to_group(&"conveyors")
	monitorable = false


func get_belt_velocity() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized() * speed


func _physics_process(_delta: float) -> void:
	var belt := get_belt_velocity()
	for body in get_overlapping_bodies():
		var robot := body as RobotBody
		if robot:
			robot.ride_belt(belt)
			continue
		var package := body as Package
		# Loose packages move with the belt (friction would fight a push).
		if package and not package.is_held() and package.linear_velocity.y < 1.0:
			package.linear_velocity = Vector3(belt.x, package.linear_velocity.y, belt.z)
			package.sleeping = false
