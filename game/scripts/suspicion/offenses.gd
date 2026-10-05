class_name Offenses
## What counts as suspicious. Being seen is fine; what you're doing when
## you're seen is what matters. Each offense has a severity: cameras react
## to everything, coworkers only to the really obvious ones.

const OFF_LIMITS := &"off_limits"
const FIGHTING := &"fighting"
const CLIMBING := &"climbing"
const CONTRABAND := &"contraband"
const ODD_HEIGHT := &"odd_height"

const SEVERITY := {
	OFF_LIMITS: 3.0,
	FIGHTING: 3.0,
	CLIMBING: 2.0,
	CONTRABAND: 2.0,
	ODD_HEIGHT: 1.0,
}

const DESCRIPTION := {
	OFF_LIMITS: "Above your clearance",
	FIGHTING: "Fighting",
	CLIMBING: "Climbing",
	CONTRABAND: "Carrying contraband",
	ODD_HEIGHT: "Resizing outside an aisle",
}

## Company standard torso extension, plus some slack.
const NORMAL_EXTENSION := 0.7
## A fight stays suspicious this long after the last blow.
const FIGHT_MEMORY := 3.0


## Offenses the robot is committing right now, mapped to their severity.
static func evaluate(robot: RobotBody) -> Dictionary:
	var found := {}
	var zones := Zone.zones_at(robot)
	var resizing_ok := false
	var clearance := GameState.clearance + Inventory.clearance_bonus(robot)
	for zone in zones:
		if zone.required_clearance > clearance:
			found[OFF_LIMITS] = SEVERITY[OFF_LIMITS]
		resizing_ok = resizing_ok or zone.allow_resize
	if robot.is_hooked or robot.is_mantling:
		found[CLIMBING] = SEVERITY[CLIMBING]
	if robot.extension > NORMAL_EXTENSION and not resizing_ok:
		found[ODD_HEIGHT] = SEVERITY[ODD_HEIGHT]
	if Inventory.shows_contraband(robot):
		found[CONTRABAND] = SEVERITY[CONTRABAND]
	if Time.get_ticks_msec() / 1000.0 - robot.last_fight_time < FIGHT_MEMORY:
		found[FIGHTING] = SEVERITY[FIGHTING]
	return found


static func describe(offenses: Dictionary) -> String:
	var names: PackedStringArray = []
	for offense in offenses:
		names.append(DESCRIPTION.get(offense, str(offense)))
	return ", ".join(names)
