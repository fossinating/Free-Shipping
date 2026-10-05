class_name CoworkerBrain
extends Node
## A robot still under the company's control. It walks its route doing
## busywork. It doesn't hunt you, but it reports anything really obvious.

@export var route: Node3D
@export var wait_time := 2.0
@export var arrive_distance := 0.6
## How long it stops and stares after reporting you.
@export var stare_time := 2.5

var _points := PackedVector3Array()
var _index := 0
var _wait := 0.0
var _stare := 0.0

@onready var robot: RobotBody = get_parent()
@onready var _eyes: Watcher = $"../Eyes"
@onready var _alert: Label3D = $"../Alert"


func _ready() -> void:
	robot.add_to_group(&"coworkers")
	_alert.hide()
	_eyes.reported.connect(_on_reported)
	if route:
		for child in route.get_children():
			if child is Node3D:
				_points.append((child as Node3D).global_position)


func _physics_process(delta: float) -> void:
	robot.move_input = Vector3.ZERO
	if _stare > 0.0:
		_stare -= delta
		_face(_eyes.target.global_position - robot.global_position)
		if _stare <= 0.0:
			_alert.hide()
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if _points.is_empty():
		return
	var to := _points[_index] - robot.global_position
	to.y = 0.0
	if to.length() < arrive_distance:
		_index = (_index + 1) % _points.size()
		_wait = wait_time
		return
	robot.move_input = to.normalized()
	_face(to)


func _face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		robot.facing_yaw = atan2(-direction.x, -direction.z)


func _on_reported(_offenses: Dictionary) -> void:
	_stare = stare_time
	_alert.show()
