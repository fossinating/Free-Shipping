extends Spatial


var target = null
var rng = RandomNumberGenerator.new()
onready var nav = $Robot/NavigationAgent
onready var robot = $Robot

var _velocity = Vector3.ZERO


func _ready():
	rng.randomize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if target == null:
		target = get_tree().get_nodes_in_group("targets")[rng.randi_range(0, get_tree().get_nodes_in_group("targets").size() - 1)]
	nav.set_target_location(target.global_transform.origin)
	
	var next_target = nav.get_next_location()
	#print(robot.global_transform.origin.distance_squared_to(next_target))
	
	#var _rotation_degrees = robot.rotation_degrees
	#robot.look_at(next_target, Vector3(0, 1, 0))
	#var target_degrees = robot.rotation_degrees
#	robot.rotation_degrees = _rotation_degrees
#	var rotation_amount = target_degrees.y - _rotation_degrees.y
	var move_direction = Vector3.ZERO
#	if abs(rotation_amount) > 0.5:
#		if rotation_amount > 180:
#			rotation_amount -= 360
#		elif rotation_amount < -180:
#			rotation_amount += 360
#		robot.rotation_degrees.y += clamp(rotation_amount, -30*delta, 30*delta)
	if robot.global_transform.origin.distance_squared_to(next_target) > pow((robot._velocity.length_squared())/(2*robot.friction), 2):
		move_direction.z = -1
		move_direction = move_direction.rotated(Vector3.UP, robot.rotation.y).normalized()
#	#robot.move_in_direction(move_direction, delta)
	
	if robot.global_transform.origin.distance_squared_to(target.global_transform.origin) < 5:
		#print("found my target")
		target = null
	nav.set_velocity(robot.global_transform.origin.direction_to(next_target) * 5)


func _on_NavigationAgent_velocity_computed(safe_velocity):
	#print(safe_velocity)
	_velocity = robot.move_and_slide_with_snap(safe_velocity, Vector3.DOWN, Vector3.UP, false, 100, 0.785398, false)
