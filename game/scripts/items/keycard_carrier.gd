class_name KeycardCarrier
extends Node
## A keycard clipped to a robot's chassis (a guard's, usually). Hit the
## robot, with a swing or a thrown package, and the card falls off. Fast,
## and loud. Attach as a child of a RobotBody.

signal dropped(card: Item)

## Which keycard it carries (keycard_1, keycard_2, ...).
@export var level := 1

var has_card := true

var _clip: MeshInstance3D

@onready var robot: RobotBody = get_parent()


func _ready() -> void:
	robot.knocked_back.connect(drop)
	# The card shows on the robot's chest.
	var def := ItemCatalog.get_def(get_card_id())
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.24, 0.16, 0.03)
	var material := StandardMaterial3D.new()
	material.albedo_color = def.get("color", Color.WHITE)
	material.emission_enabled = true
	material.emission = def.get("color", Color.WHITE)
	material.emission_energy_multiplier = 0.4
	mesh.material = material
	_clip = MeshInstance3D.new()
	_clip.name = "Keycard"
	_clip.mesh = mesh
	_clip.position = Vector3(0.22, 0.05, -RobotBody.CORE_HALF_DEPTH - 0.02)
	robot.get_node(^"Visual/Core").add_child.call_deferred(_clip)


func get_card_id() -> StringName:
	return StringName("keycard_%d" % level)


## Knocks the card loose. Returns the pickup, or null if it's already gone.
func drop() -> Item:
	if not has_card:
		return null
	has_card = false
	_clip.hide()
	# Into the level, not under the guard (which may be paused).
	var parent: Node = robot.owner if robot.owner else robot.get_parent()
	var card := Item.spawn(ItemState.new(get_card_id()), parent,
		robot.get_core_position() + Vector3.UP * 0.6)
	card.linear_velocity = Vector3(randf_range(-1.0, 1.0), 3.0, randf_range(-1.0, 1.0))
	dropped.emit(card)
	return card


## Takes the card away quietly (a loaded game where you already have it).
func remove_card() -> void:
	has_card = false
	if _clip:
		_clip.hide()
