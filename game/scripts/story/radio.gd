class_name Radio
extends Node3D
## Elle's radio: the source of the static your fried chip picks up. The
## closer you are, the stronger the signal. Get your core right up to it
## and you tune in.

## Your core came close enough to tune in.
signal tuned_in

## Beyond this distance there's no signal at all.
@export var signal_range := 40.0
## How close your core has to get to tune in.
@export var tune_distance := 1.3

## Only tunes in once the story allows it (after the diagnostics).
var listening := false
var is_found := false

@onready var _light: MeshInstance3D = $Light


func _ready() -> void:
	add_to_group(&"signal_sources")


## Signal strength (0 to 1) at a point. Rises steeply near the radio.
func strength_at(point: Vector3) -> float:
	var t := clampf(1.0 - global_position.distance_to(point) / signal_range, 0.0, 1.0)
	return pow(t, 1.5)


func is_in_tune_range(robot: RobotBody) -> bool:
	return robot.get_core_position().distance_to(global_position) <= tune_distance


func _process(_delta: float) -> void:
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.15
	_light.visible = blink or is_found


func _physics_process(_delta: float) -> void:
	if not listening or is_found:
		return
	var player := get_tree().get_first_node_in_group(&"player") as RobotBody
	if player and is_in_tune_range(player):
		is_found = true
		tuned_in.emit()


## The strongest signal at a point, over every source in the level.
static func strongest_at(tree: SceneTree, point: Vector3) -> float:
	var best := 0.0
	for source: Radio in tree.get_nodes_in_group(&"signal_sources"):
		best = maxf(best, source.strength_at(point))
	return best
