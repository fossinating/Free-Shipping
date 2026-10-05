class_name PlayerController
extends Node
## Turns player input into intent for the robot body it is attached to,
## and drives its inventory and charging dock.

## Something happened worth a short line on the HUD.
signal notice(text: String)

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

## The dock whose panel is open, or null. Movement stops while it's open.
var open_dock: ChargingDock = null:
	set(value):
		open_dock = value
		robot.move_input = Vector3.ZERO
		robot.extension_input = 0.0
		robot.arms_input = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

var _charging := false
var _charge := 0.0

@onready var robot: RobotBody = get_parent()
@onready var inventory: Inventory = Inventory.of(robot)


func _ready() -> void:
	camera.target = robot
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if inventory:
		inventory.message.connect(notice.emit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and open_dock == null \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# Installed upgrades change how the body moves.
	robot.wheels = GameState.has_upgrade(&"wheel_base")
	robot.magnetic_hands = GameState.has_upgrade(&"magnetic_hands")
	if not enabled:
		return
	if open_dock:
		if Input.is_action_just_pressed("open_dock") or Input.is_action_just_pressed("pause") \
				or not open_dock.is_in_reach(robot):
			open_dock = null
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
	if inventory and not _controlled():
		_update_items()


func _update_items() -> void:
	if Input.is_action_just_pressed("cycle_item"):
		inventory.cycle()
	if Input.is_action_just_pressed("stow"):
		if robot.held:
			_charging = false
			inventory.stow_held()
		elif inventory.get_equipped():
			inventory.take_out()
	if Input.is_action_just_pressed("use_item"):
		var text := inventory.use_equipped()
		if text != "":
			notice.emit(text)
	if Input.is_action_just_pressed("open_dock"):
		var dock := ChargingDock.find_near(robot)
		if dock:
			open_dock = dock


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
	if open_dock:
		return ""
	if robot.is_hooked:
		if robot.is_clinging:
			return "Hold E to climb the metal"
		if robot.extension > 0.01:
			return "Hold Q to shrink and pull yourself up"
		return "Keep holding Q to climb up"
	if robot.held:
		if _charging and _charge >= TAP_TIME and (not _controlled() or program.allows_throw()):
			return "Release to throw"
		if robot.held is Item and inventory and not _controlled():
			return "R to stow  ·  Click / F to set down, hold to throw"
		return "Click / F to set down, hold to aim and throw"
	if robot.find_grab_target():
		return "Click / F to grab"
	if inventory and not _controlled() and ChargingDock.find_near(robot):
		return "C to open your dock"
	if not robot.arms_input and robot.find_grab_target(robot.max_arm_reach):
		return "Hold Shift / Right Mouse to reach further"
	if robot.is_ledge_in_reach():
		return "Hold Shift / Right Mouse to grab the ledge"
	if robot.magnetic_hands and robot.is_metal_in_reach():
		return "Hold Shift / Right Mouse to stick to the metal"
	return ""


func _controlled() -> bool:
	return program != null and program.active


func _gravity() -> Vector3:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	return Vector3.DOWN * gravity * (robot.held.gravity_scale if robot.held else 1.0)
