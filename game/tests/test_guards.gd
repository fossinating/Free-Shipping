extends TestCase
## Guards, lockdown, hiding and noise.

const LEVEL := "res://scenes/levels/stealth_test.tscn"
const PACKAGE := "res://scenes/work/package.tscn"

var level: Node3D
var robot: RobotBody


func _start() -> void:
	level = spawn(LEVEL)
	robot = level.get_node("Player")
	(level.get_node("Player/Controller") as PlayerController).enabled = false
	for node in tree.get_nodes_in_group(&"coworkers"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for camera in level.get_node("Security").get_children():
		camera.process_mode = Node.PROCESS_MODE_DISABLED
	# Wait for the navmesh bake.
	await seconds(0.3)


func _teleport(pos: Vector3, yaw := 0.0) -> void:
	robot.global_position = pos
	robot.rotation.y = yaw
	robot.facing_yaw = yaw
	robot.velocity = Vector3.ZERO
	await physics_frames(3)


func _guard(name: String) -> RobotBody:
	return level.get_node("Guards/" + name)


func _brain(name: String) -> GuardBrain:
	return level.get_node("Guards/%s/Brain" % name)


func test_maxed_suspicion_starts_lockdown() -> void:
	await _start()
	var started := [0]
	Security.lockdown_started.connect(func() -> void: started[0] += 1)
	Suspicion.add(Suspicion.MAX, "test")
	check(Security.lockdown and started[0] == 1, "maxing suspicion starts a lockdown")
	await physics_frames(2)
	check(_brain("FloorGuard").state == GuardBrain.State.SEARCH, "guards start searching")


func test_guard_chases_and_catches() -> void:
	await _start()
	var guard := _guard("FloorGuard")
	var caught := [0]
	Security.caught.connect(func() -> void: caught[0] += 1)
	# Put the player in front of the guard, then trigger the lockdown.
	await _teleport(guard.global_position + guard.get_forward() * 5.0)
	Security.start_lockdown()
	await physics_frames(3)
	check(_brain("FloorGuard").state == GuardBrain.State.CHASE, "a guard that sees you gives chase")
	await seconds(3.0)
	check(caught[0] == 1, "and catches you if you stand still")
	check(not Security.lockdown, "being caught ends the lockdown")


func test_guard_paths_around_obstacles() -> void:
	await _start()
	var guard := _guard("FloorGuard")
	var brain := _brain("FloorGuard")
	_guard("OfficeGuard").process_mode = Node.PROCESS_MODE_DISABLED
	# Blind it so it searches instead of chasing the player.
	guard.get_node("Visual/Core/Eyes").process_mode = Node.PROCESS_MODE_DISABLED
	# Behind CrateA (at -3, -4) from the guard's point of view.
	await _teleport(Vector3(-8, 0.05, -12))
	guard.global_position = Vector3(-3, 0.05, 0)
	brain._set_state(GuardBrain.State.INVESTIGATE, Vector3(-3, 0, -8))
	await seconds(4.0)
	var flat := Vector2(guard.global_position.x + 3, guard.global_position.z + 8)
	check(flat.length() < 3.0, "the guard walks around the crate (at %s)" % guard.global_position)


func test_lockdown_ends_when_unseen_and_blending_helps() -> void:
	await _start()
	for guard in tree.get_nodes_in_group(&"guards"):
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	var zone: Zone = level.get_node("Zones/SecurityOffice")
	await _teleport(Vector3(13, 0.05, -12))
	Security.lockdown_end_time = 2.0
	Suspicion.add(Suspicion.MAX, "test")
	check(Security.heightened_zone == zone, "the lockdown is pinned to the most specific zone")
	await seconds(1.0)
	check(Security.lockdown, "still on after 1 s")
	await seconds(1.3)
	check(not Security.lockdown, "ends after 2 s unseen")
	check(is_equal_approx(Suspicion.value, Security.aftermath_suspicion), "suspicion stays high")
	check(Security.get_alert_multiplier(Vector3(13, 1, -12)) > 1.0, "the zone is on alert")
	check(Security.get_alert_multiplier(Vector3(0, 1, 10)) == 1.0, "other zones aren't")

	var package: Package = load(PACKAGE).instantiate()
	level.add_child(package)
	package.global_position = robot.get_hold_position()
	robot.grab(package)
	Suspicion.add(Suspicion.MAX, "test")
	check(Security.lockdown, "a second lockdown can start")
	await seconds(1.2)
	check(not Security.lockdown, "carrying stock blends in and ends it twice as fast")


func test_hiding_spot_hides_from_cameras() -> void:
	await _start()
	await _teleport(Vector3(-17, 0.05, 14.5))
	var watcher: Watcher = level.get_node("Security/FloorCamera/Head/Watcher")
	var eye := watcher.global_position
	check(not HidingSpot.is_hidden(robot), "standing tall isn't hiding")
	robot.extension_input = -1.0
	await seconds(0.5)
	check(HidingSpot.is_hidden(robot), "shrinking down inside the stack hides you")
	check(not watcher.can_see(robot), "a camera can't see a hidden robot")
	watcher.global_position = robot.global_position + Vector3(0, 1.0, 0.9)
	watcher.look_at(robot.get_core_position())
	check(watcher.can_see(robot), "unless it's right next to you")
	watcher.global_position = eye


func test_noise_draws_a_guard() -> void:
	await _start()
	var brain := _brain("FloorGuard")
	var spot := _guard("FloorGuard").global_position + Vector3(4, 0, 2)
	Security.make_noise(spot, 10.0)
	check(brain.state == GuardBrain.State.INVESTIGATE, "a guard investigates a noise in range")
	check(_brain("OfficeGuard").state == GuardBrain.State.PATROL, "guards out of range don't")
	await seconds(3.0)
	check(_guard("FloorGuard").global_position.distance_to(spot) < 2.0, "it walks to the noise")


func test_thrown_package_makes_noise() -> void:
	await _start()
	var heard := []
	Security.noise.connect(func(at: Vector3, _radius: float) -> void: heard.append(at))
	var package: Package = load(PACKAGE).instantiate()
	level.add_child(package)
	package.global_position = Vector3(0, 3, 10)
	package.linear_velocity = Vector3(0, -8, 0)
	await seconds(1.0)
	check(not heard.is_empty(), "a hard landing makes noise")


func test_falling_behind_sends_a_guard_to_check_in() -> void:
	await _start()
	_guard("OfficeGuard").process_mode = Node.PROCESS_MODE_DISABLED
	await _teleport(Vector3(-4, 0.05, -6))
	Quota.expected_interval = 0.1
	await seconds(0.5)
	check(_brain("FloorGuard").state == GuardBrain.State.CHECK_IN, "a guard comes to check")
	await seconds(3.0)
	var distance := _guard("FloorGuard").global_position.distance_to(robot.global_position)
	check(distance < 3.5, "it walks up to you (%.1f m)" % distance)
	check(not Security.lockdown, "a check-in isn't a lockdown")
