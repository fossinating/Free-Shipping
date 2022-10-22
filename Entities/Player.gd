extends Robot

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_lookaround(false)


var arms_out = false
var lookaround = false
var throwing = false
var throw_charge = 0.0
export var min_throw_charge = 20.0
export var max_throw_charge = 60.0
export var throw_charge_rate = 20.0

func _physics_process(delta):
	#var rotation_vel = (Input.get_action_strength("movement_left") - Input.get_action_strength("movement_right")) * rotation_speed
	
	#robot.rotation_degrees.y += rotation_vel * delta
	
	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_action_strength("movement_right") - Input.get_action_strength("movement_left")
	move_direction.z = Input.get_action_strength("movement_back") - Input.get_action_strength("movement_forward")
	move_direction = move_direction.rotated(Vector3.UP, global_rotation.y).normalized()
	move_in_direction(move_direction, delta)
	
	var ext_vel = 0
	if Input.is_action_pressed("extend"):
		ext_vel += extension_speed
	if Input.is_action_pressed("retract"):
		ext_vel -= extension_speed
	extend(ext_vel*delta)
	# make third person toggleable
	var toggle_lookaround = true
	if toggle_lookaround:
		if Input.is_action_just_pressed("lookaround"):
			set_lookaround(!lookaround)
	else:
		if Input.is_action_just_released("lookaround"):
			set_lookaround(true)
		if Input.is_action_just_pressed("lookaround"):
			set_lookaround(false)
	if Input.is_action_just_pressed("reach") and !arms_out and held_item == null:
		arms_out = true
		arms_out()
	if Input.is_action_just_released("reach") and arms_out and held_item == null:
		arms_out = false
		arms_in()
	if Input.is_action_just_pressed("interact"):
		
		
		# if no other interactions, pick up any box you can
		if held_item == null:
			for node in $"Core/Right Arm Root/Pickup Area".get_overlapping_bodies():
				if node is Box:
					pickup_box(node)
					break
	if Input.is_action_just_pressed("throw") and held_item != null:
		throwing = true
		throw_charge = min_throw_charge
	if Input.is_action_pressed("throw") and throwing:
		throw_charge = min(throw_charge + delta*throw_charge_rate, max_throw_charge)
	if Input.is_action_just_released("throw") and throwing:
		held_item.linear_velocity = _velocity
		held_item.throw(-throw_charge*Vector3(0, 0, 1).rotated(Vector3(1,0,0), max(0, camera_manager.rotation.x)).rotated(Vector3.UP, global_rotation.y).normalized())
		set_held_item(null)
		throwing = false
		$AnimationPlayer.play("RESET")
		arms_out = false

func set_held_item(item):
	if item == null:
		pass
	if item != null:
		pass
	.set_held_item(item)


func 


func set_lookaround(_lookaround):
	lookaround = _lookaround
	if _lookaround:
		$"Core/Third-Person Camera/ClippedCamera".translation.z = 5
		$"Core/Core Mesh".visible = true
		$"Legs".visible = true
	else:
		$"Core/Third-Person Camera/ClippedCamera".translation.z = 0
		camera_manager.rotation_degrees.y = 0
		$"Core/Core Mesh".visible = false
		$"Legs".visible = false

var mouse_sensitivity = 0.15
var camera_anglev=0
onready var camera_manager = $"Core/Third-Person Camera"

func _input(event):
	if event is InputEventMouseMotion:
		camera_manager.rotation_degrees.x -= event.relative.y * mouse_sensitivity
		camera_manager.rotation_degrees.x = clamp(camera_manager.rotation_degrees.x, -90.0, 60)
		
		if lookaround:
			camera_manager.rotation_degrees.y -= event.relative.x * mouse_sensitivity
			camera_manager.rotation_degrees.y = wrapf(camera_manager.rotation_degrees.y, 0.0, 360.0)
		else:
			rotation_degrees.y -= event.relative.x * mouse_sensitivity
			rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)
