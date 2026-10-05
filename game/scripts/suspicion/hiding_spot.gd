class_name HidingSpot
extends Area3D
## A gap between stacked boxes or under a shelf. Shrink down inside one and
## watchers can't see you unless they're right next to you.

## Torso extension at or below which you count as tucked in.
const TUCKED_EXTENSION := 0.15
## Watchers closer than this still spot a hidden robot.
const SPOT_DISTANCE := 1.8


func _ready() -> void:
	add_to_group(&"hiding_spots")
	monitorable = false


static func is_hidden(robot: RobotBody) -> bool:
	if robot.extension > TUCKED_EXTENSION:
		return false
	for spot: HidingSpot in robot.get_tree().get_nodes_in_group(&"hiding_spots"):
		if spot.overlaps_body(robot):
			return true
	return false
