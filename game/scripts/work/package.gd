class_name Package
extends RigidBody3D
## A box on its way somewhere. Robots grab, carry and throw these, and
## chutes take them in.

## Colors for each destination tag, shared with chutes.
const DESTINATION_COLORS := {
	&"": Color(0.72, 0.55, 0.36),
	&"red": Color(0.85, 0.25, 0.22),
	&"blue": Color(0.25, 0.45, 0.9),
	&"green": Color(0.3, 0.75, 0.35),
}

## Which chute this package belongs in. Empty means any chute.
@export var destination: StringName = &"":
	set(value):
		destination = value
		if is_node_ready():
			_update_label()
@export var size := Vector3(0.6, 0.45, 0.6)
## Carrying this in plain sight is suspicious.
@export var contraband := false
## Hitting something faster than this (m/s) makes a noise guards hear.
@export var loud_impact_speed := 5.0
@export var noise_radius := 10.0
## Thrown into a robot faster than this (m/s), it knocks them back.
@export var hurt_speed := 5.5
## Seconds a robot hit by this is stunned.
@export var hurt_stun := 0.8

var holder: Node3D = null
## Who threw this, until it first hits something.
var thrown_by: RobotBody = null
# Speed before this frame's collisions resolved, for impact noise. Contact
# signals can arrive a frame after the impact, so this covers two frames.
var _speed_before_contact := 0.0
var _last_frame_speed := 0.0
## What produced this package, such as a PackageSpawner. Tasks use it to
## tell which packages belong to them.
var source: Node = null

@onready var _shape: CollisionShape3D = $Shape
@onready var _mesh: MeshInstance3D = $Mesh
@onready var _label: MeshInstance3D = $Label


func _ready() -> void:
	add_to_group(&"packages")
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh.mesh = mesh
	_label.position.y = size.y / 2.0 + 0.005
	_update_label()
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)


func is_held() -> bool:
	return holder != null


## Normal stock a loyal worker would carry. Carrying it helps blend in.
func is_stock() -> bool:
	return not contraband


## Picked up: stop simulating and stop colliding until let go.
func attach(by: Node3D) -> void:
	holder = by
	freeze = true
	collision_layer = 0
	collision_mask = 0


func detach(launch_velocity: Vector3, by: RobotBody = null) -> void:
	holder = null
	thrown_by = by
	freeze = false
	collision_layer = 1
	collision_mask = 1
	linear_velocity = launch_velocity
	angular_velocity = Vector3.ZERO
	# A point-blank throw can hit before the next physics frame records it.
	_speed_before_contact = launch_velocity.length()
	_last_frame_speed = _speed_before_contact


func _update_label() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = DESTINATION_COLORS.get(destination, Color.WHITE)
	_label.material_override = material


func _physics_process(_delta: float) -> void:
	var speed := linear_velocity.length()
	_speed_before_contact = maxf(speed, _last_frame_speed)
	_last_frame_speed = speed


func _on_body_entered(body: Node) -> void:
	var speed := maxf(_speed_before_contact, linear_velocity.length())
	if speed > loud_impact_speed:
		Security.make_noise(global_position, noise_radius)
	var robot := body as RobotBody
	if robot and robot != thrown_by and thrown_by != null and speed > hurt_speed:
		_hurt(robot, speed)
	thrown_by = null


## Hit a robot hard enough to knock it back.
func _hurt(robot: RobotBody, speed: float) -> void:
	Combat.hit(thrown_by, robot, linear_velocity, minf(speed * 0.6, 8.0), hurt_stun)
