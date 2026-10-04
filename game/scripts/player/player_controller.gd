class_name PlayerController
extends Node
## Turns player input into intent for the robot body it is attached to.

@export var camera: PlayerCamera

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


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	robot.move_input = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera.yaw)
	robot.extension_input = Input.get_axis("shrink", "grow")
	robot.arms_input = Input.is_action_pressed("extend_arms")
	robot.facing_yaw = camera.yaw


## Short hint for whatever the player can do right now, or "" for none.
func get_prompt() -> String:
	if robot.is_hooked:
		if robot.extension > 0.01:
			return "Hold Q to shrink and pull yourself up"
		return "Keep holding Q to climb up"
	if robot.is_ledge_in_reach():
		return "Hold Shift / Right Mouse to grab the ledge"
	return ""
