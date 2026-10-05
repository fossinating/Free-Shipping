class_name ScannerCheckpoint
extends Area3D
## A badge scanner at a zone door. Step into it and it reads your badge
## and everything you carry. Enough clearance opens the door; contraband,
## even stowed away, is logged and raises suspicion whether or not the door
## opens. The door closes again once you're out of the scanner.
##
## Office doors use the same thing as a plain badge reader
## (`check_contraband` off).

## Read the player's badge. `granted` is whether the door opened.
signal scanned(granted: bool, contraband: bool)

@export var door: Door
@export var required_clearance := 1
## What's behind the door, for the HUD ("Receiving").
@export var place_name := ""
@export var check_contraband := true
@export var contraband_suspicion := 25.0
## Swiping a badge that's too low is a little suspicious too.
@export var denied_suspicion := 6.0
## Seconds after you leave the scanner before the door closes.
@export var close_delay := 1.5
## A sign that turns green once your badge would get through.
@export var status_sign: Label3D

var _inside := false
var _empty_time := 0.0


func _ready() -> void:
	add_to_group(&"checkpoints")
	monitorable = false
	GameState.clearance_changed.connect(_on_clearance_changed)
	_update_sign()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as RobotBody
	var inside := player != null and overlaps_body(player)
	if inside and not _inside:
		scan(player)
	_inside = inside
	if inside:
		_empty_time = 0.0
	elif door and door.is_open:
		_empty_time += delta
		if _empty_time >= close_delay:
			door.close()


## The clearance a scanner reads for this robot (a fake ID adds to it).
static func badge_level(robot: RobotBody) -> int:
	return GameState.clearance + Inventory.clearance_bonus(robot)


func would_grant(robot: RobotBody) -> bool:
	return badge_level(robot) >= required_clearance


## Reads the robot's badge and what it carries. Returns whether it may pass.
func scan(robot: RobotBody) -> bool:
	var granted := would_grant(robot)
	var contraband := check_contraband and Inventory.carries_contraband(robot)
	if contraband:
		Suspicion.add(contraband_suspicion, "Scanner logged contraband")
	if granted:
		if door:
			door.open()
	else:
		Suspicion.add(denied_suspicion, "Badge rejected")
	scanned.emit(granted, contraband)
	return granted


func _on_clearance_changed(_level: int) -> void:
	_update_sign()
	# A new card swiped while standing in the scanner opens it right away.
	var player := get_tree().get_first_node_in_group(&"player") as RobotBody
	if _inside and player and would_grant(player) and door:
		door.open()


func _update_sign() -> void:
	if status_sign == null:
		return
	var ok := GameState.clearance >= required_clearance
	status_sign.modulate = Color(0.5, 1.0, 0.55) if ok else Color(1.0, 0.45, 0.35)
