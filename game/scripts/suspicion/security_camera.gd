class_name SecurityCamera
extends Node3D
## A ceiling camera. Fixed or sweeping. It can't chase, but anything
## suspicious in its view raises the meter. Its spotlight shows what it
## covers and changes color when it sees something.

const COLOR_IDLE := Color(0.5, 1.0, 0.6)
const COLOR_ALARM := Color(1.0, 0.3, 0.2)

## Total sweep angle. 0 keeps the camera fixed.
@export var sweep_degrees := 0.0
@export var sweep_speed_degrees := 20.0
## Pause at each end of the sweep.
@export var sweep_pause := 1.5

var _base_yaw := 0.0
var _direction := 1.0
var _pause := 0.0

@onready var _head: Node3D = $Head
@onready var _watcher: Watcher = $Head/Watcher
@onready var _light: SpotLight3D = $Head/Light


func _ready() -> void:
	_base_yaw = _head.rotation.y
	_light.spot_angle = _watcher.fov_degrees / 2.0
	_light.spot_range = _watcher.view_range
	_light.light_color = COLOR_IDLE
	_watcher.alarm_changed.connect(func(alarmed: bool) -> void:
		_light.light_color = COLOR_ALARM if alarmed else COLOR_IDLE)


func _physics_process(delta: float) -> void:
	if sweep_degrees <= 0.0:
		return
	# Hold still while watching something suspicious.
	if _watcher.alarmed:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var half := deg_to_rad(sweep_degrees) / 2.0
	var yaw := _head.rotation.y + _direction * deg_to_rad(sweep_speed_degrees) * delta
	if absf(yaw - _base_yaw) >= half:
		yaw = _base_yaw + half * _direction
		_direction = -_direction
		_pause = sweep_pause
	_head.rotation.y = yaw
