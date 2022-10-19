extends KinematicBody


export var accel := 5
export var max_air_speed := 15.0
export var max_ground_speed := 10.0
export var jump_strength := 20.0
export var gravity := 50.0
export var friction := 0.1
export var max_extension := 5
export var extension_speed := 1
export var rotation_speed := 30

var _extension := 0.0
var _velocity := Vector3.ZERO
var _snap_vector := Vector3.DOWN


func _ready():
	$Legs.shape = $Legs.shape.duplicate(true)


func move_in_direction(move_direction, delta):
	var max_speed = max_air_speed
	if is_on_floor():
		max_speed = max_ground_speed
	
	var accel_adjust = 1
	if !is_on_floor():
		accel_adjust = 0.1
	
	_velocity.x = lerp(_velocity.x, move_direction.x * max_speed, accel*accel_adjust*delta)
	_velocity.z = lerp(_velocity.z, move_direction.z * max_speed, accel*accel_adjust*delta)
	
	var horiz_vel = Vector2(_velocity.x, _velocity.z)
	if (horiz_vel.length() != 0):
		horiz_vel = horiz_vel / horiz_vel.length() * clamp(horiz_vel.length(), -max_speed, max_speed)
	
	if is_on_floor():
		horiz_vel.x = lerp(horiz_vel.x, 0, friction)
		horiz_vel.y = lerp(horiz_vel.y, 0, friction)
	
	_velocity = Vector3(horiz_vel.x, _velocity.y, horiz_vel.y)
	
	_velocity.y = clamp(_velocity.y - gravity * delta, -100, 100)
	
	var just_landed := is_on_floor() and _snap_vector == Vector3.ZERO
	# leaving this in just in case i add jumping as a powerup
	var is_jumping := false and is_on_floor() and Input.is_action_pressed("movement_jump")
	
	if is_jumping:
		_velocity.y = jump_strength
		_snap_vector = Vector3.ZERO
	elif just_landed:
		_snap_vector = Vector3.DOWN
	_velocity = move_and_slide_with_snap(_velocity, _snap_vector, Vector3.UP, false, 100, 0.785398, false)


func extend(amount):
	_extension = clamp(_extension + amount, 0, max_extension)
	
	$Core.translation.y = _extension
	$Legs.shape.extents.y = _extension
	$"Legs/Leg Mesh".scale.y = max(1.25*_extension, 0.001)
	$"Legs/Leg Mesh".translation.y = -1*_extension
	$Treads.translation.y = -_extension - 0.825
	#$"Left Arm Root".translation.y = _extension + .45
	#$"Right Arm Collision".translation.y = _extension + .45
	
	$"Core/Third-Person Camera".scale.z = 1 + _extension * 0.5

func arms_out():
	$AnimationPlayer.play("ArmsOut")

func arms_in():
	$AnimationPlayer.play("ArmsIn")

var held_item = null
onready var tween = $Tween

func pickup_box(node):
	held_item = node
	# disable the collision when picking the box up
	node.get_node("CollisionShape").disabled = true
	node.get_parent().remove_child(node)
	node.translation = Vector3(0,0,0)
	$"Core/Right Arm Root/Box Holder/Offset".add_child(node)
	$"AnimationPlayer".play("Pickup")
	tween.interpolate_property(node, "rotation_degrees",
		node.rotation_degrees, Vector3(0, 0, 0), 0.2,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	#tween.start()

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "Pickup":
		# i may want to have it re-enable the collision later but for now that is too complicated
		pass
		#held_item.get_node("CollisionShape").disabled = false
