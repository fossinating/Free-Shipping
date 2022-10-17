extends Spatial


# Declare member variables here. Examples:
onready var robot = $Robot
onready var rotation_speed = robot.rotation_speed
onready var extension_speed = robot.extension_speed

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _physics_process(delta):
	var rotation_vel = (Input.get_action_strength("movement_left") - Input.get_action_strength("movement_right")) * rotation_speed
	
	robot.rotation_degrees.y += rotation_vel * delta
	
	var move_direction := Vector3.ZERO
	#move_direction.x = Input.get_action_strength("movement_right") - Input.get_action_strength("movement_left")
	move_direction.z = Input.get_action_strength("movement_back") - Input.get_action_strength("movement_forward")
	move_direction = move_direction.rotated(Vector3.UP, robot.rotation.y).normalized()
	robot.move_in_direction(move_direction, delta)
	
	var ext_vel = 0
	if Input.is_action_pressed("extend"):
		ext_vel += extension_speed
	if Input.is_action_pressed("retract"):
		ext_vel -= extension_speed
	robot.extend(ext_vel*delta)
