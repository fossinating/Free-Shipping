class_name ShiftStep
extends Marker3D
## One assigned task in a shift. The step's position is where the task
## happens; child Marker3Ds are waypoints of the route the robot must keep
## to on the way there. While the step is active, control mode only allows
## what the step's permissions say.

enum Kind {
	## Get within `radius` of this step.
	REACH,
	## Pick up a package from `target` (a PackageSpawner), or any package.
	GRAB,
	## Deliver `count` packages into `target` (a Chute), or into any chute.
	DELIVER,
	## Press `target` (a PushButton).
	PRESS,
	## Walk into the accident at this step. Ends control mode.
	ACCIDENT,
}

@export_multiline var instruction := ""
@export var kind := Kind.REACH
@export var target: Node3D
@export var count := 1
## Packages from here may be grabbed during this step (besides the one
## you were already carrying).
@export var source: PackageSpawner
## Inside this radius of the step, movement isn't restricted.
@export var radius := 1.5
@export var corridor_width := 3.0

@export_group("Allowed")
@export var allow_move := true
@export var allow_arms := false
@export var allow_throw := false
## Highest torso extension allowed. Company standard height is 0.4.
@export var max_extension := 0.4


func get_waypoints() -> PackedVector3Array:
	var points := PackedVector3Array()
	for child in get_children():
		if child is Marker3D:
			points.append((child as Marker3D).global_position)
	points.append(global_position)
	return points


## Where packages for this step can come from, or null for none.
func get_package_source() -> Node:
	if source:
		return source
	if kind == Kind.GRAB:
		return target
	return null
