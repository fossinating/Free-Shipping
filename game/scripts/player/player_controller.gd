class_name PlayerController
extends Node
## Turns player input into intent for the robot body it is attached to.

## Presses shorter than this set a package down instead of throwing it.
const TAP_TIME := 0.18

@export var camera: PlayerCamera
@export var throw_arc: ThrowArc
## Control mode, if the robot is still under the company's control.
@export var program: ControlProgram
@export var min_throw_speed := 5.0
@export var max_throw_speed := 14.0
## Seconds of holding to reach full throw speed.
@export var full_charge_time := 0.8
## Throws aim this much higher than the camera looks.
@export var throw_lift := deg_to_rad(25.0)

## Cutscenes turn this off to take the robot's controls away.
var enabled := true:
	set(value):
		enabled = value
		if not value:
			robot.move_input = Vector3.ZERO
			robot.extension_input = 0.0
			robot.arms_input = false
			_charging = false
			throw_arc.hide()

var _charging := false
var _charge := 0.0

@onready var robot: RobotBody = get_parent()


func _ready() -> void:
	camera.target = robot
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera.yaw)
	var resize := Input.get_axis("shrink", "grow")
	var arms := Input.is_action_pressed("extend_arms")
	if _controlled():
		move = program.filter_move(move)
		arms = program.filter_arms(arms)
		if resize > 0.0 and robot.extension >= robot.extension_limit - 0.01:
			program.deny("Height change not authorized")
	robot.move_input = move
	robot.extension_input = resize
	robot.arms_input = arms
	robot.facing_yaw = camera.yaw
	_update_hands(delta)


func _update_hands(delta: float) -> void:
	if not robot.held:
		_charging = false
		throw_arc.hide()
		if Input.is_action_just_pressed("interact"):
			var target := robot.find_grab_target()
			if target and (not _controlled() or program.can_grab(target)):
				robot.grab(target)
		return
	if Input.is_action_just_pressed("interact"):
		_charging = true
		_charge = 0.0
	if not _charging:
		return
	_charge += delta
	var may_throw := not _controlled() or _charge < TAP_TIME or program.can_throw()
	if Input.is_action_pressed("interact"):
		if _charge >= TAP_TIME and may_throw:
			throw_arc.draw(ThrowArc.predict(robot.get_world_3d().direct_space_state,
				robot.get_hold_position(), get_throw_velocity(), _gravity(),
				[robot.get_rid(), robot.held.get_rid()]))
		return
	_charging = false
	throw_arc.hide()
	if _charge < TAP_TIME or not may_throw:
		robot.drop()
	else:
		robot.throw(get_throw_velocity())


func get_throw_velocity() -> Vector3:
	var strength := clampf((_charge - TAP_TIME) / full_charge_time, 0.0, 1.0)
	var speed := lerpf(min_throw_speed, max_throw_speed, strength)
	var elevation := clampf(camera.pitch + throw_lift, deg_to_rad(-5.0), deg_to_rad(60.0))
	var direction := Basis(Vector3.UP, camera.yaw) * Basis(Vector3.RIGHT, elevation) \
		* Vector3.FORWARD
	return direction * speed + Vector3(robot.velocity.x, 0.0, robot.velocity.z)


## Short hint for whatever the player can do right now, or "" for none.
func get_prompt() -> String:
	if robot.is_hooked:
		if robot.extension > 0.01:
			return "Hold Q to shrink and pull yourself up"
		return "Keep holding Q to climb up"
	if robot.held:
		if _charging and _charge >= TAP_TIME and (not _controlled() or program.allows_throw()):
			return "Release to throw"
		return "Click / F to set down, hold to aim and throw"
	if robot.find_grab_target():
		return "Click / F to grab"
	if not robot.arms_input and robot.find_grab_target(robot.max_arm_reach):
		return "Hold Shift / Right Mouse to reach further"
	if robot.is_ledge_in_reach():
		return "Hold Shift / Right Mouse to grab the ledge"
	return ""


func _controlled() -> bool:
	return program != null and program.active


func _gravity() -> Vector3:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	return Vector3.DOWN * gravity * (robot.held.gravity_scale if robot.held else 1.0)
