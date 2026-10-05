class_name Combat
## Physics-based fighting: swinging found tools and throwing things at
## other robots. Every blow is loud and marks both robots as fighting.

## Guards within this distance of a blow come to look.
const NOISE_RADIUS := 12.0
## How far in front of the core a swing reaches.
const SWING_REACH := 1.9
const SWING_CONE_DEGREES := 70.0


## `victim` takes a blow from `attacker` (null for nobody in particular),
## pushed along `direction` at `knockback` m/s and stunned for `stun` s.
static func hit(attacker: RobotBody, victim: RobotBody, direction: Vector3,
		knockback: float, stun: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	victim.last_fight_time = now
	if attacker:
		attacker.last_fight_time = now
		if attacker.is_in_group(&"player"):
			GameState.note_fight()
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01 and attacker:
		flat = victim.global_position - attacker.global_position
		flat.y = 0.0
	victim.knock_back(flat.normalized() * knockback, stun)
	Security.make_noise(victim.global_position, NOISE_RADIUS)


## The robot a swing from `attacker` would hit, or null.
static func find_swing_target(attacker: RobotBody) -> RobotBody:
	var core := attacker.get_core_position()
	var forward := attacker.get_forward()
	var best: RobotBody = null
	var best_distance := INF
	for robot: RobotBody in attacker.get_tree().get_nodes_in_group(&"robots"):
		if robot == attacker:
			continue
		var offset := robot.get_core_position() - core
		# Short robots can still be hit from a taller one, and vice versa.
		var flat := Vector3(offset.x, 0.0, offset.z)
		var distance := flat.length()
		if distance > SWING_REACH + RobotBody.CORE_HALF_DEPTH:
			continue
		if absf(robot.global_position.y - attacker.global_position.y) > 2.0:
			continue
		if distance > 0.3 and forward.angle_to(flat) > deg_to_rad(SWING_CONE_DEGREES) / 2.0:
			continue
		if distance < best_distance:
			best_distance = distance
			best = robot
	return best


## Swings `tool` (an ItemState) from `attacker`. Wears the tool whether or
## not it connects. Returns the robot it hit, or null.
static func swing(attacker: RobotBody, tool: ItemState) -> RobotBody:
	if tool == null or tool.get_kind() != ItemCatalog.Kind.TOOL or tool.is_broken():
		return null
	tool.wear()
	var def := tool.get_def()
	var victim := find_swing_target(attacker)
	if victim:
		hit(attacker, victim, attacker.get_forward(), def.get("damage", 6.0), def.get("stun", 1.0))
	else:
		# Whiffing is still loud.
		Security.make_noise(attacker.global_position, NOISE_RADIUS * 0.5)
	return victim
