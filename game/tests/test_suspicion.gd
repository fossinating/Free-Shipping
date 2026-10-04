extends TestCase
## Offenses, watchers, cameras, coworkers and the suspicion meter.

const LEVEL := "res://scenes/levels/stealth_test.tscn"
const PACKAGE := "res://scenes/work/package.tscn"

var level: Node3D
var robot: RobotBody


func _start() -> void:
	level = spawn(LEVEL)
	robot = level.get_node("Player")
	(level.get_node("Player/Controller") as PlayerController).enabled = false
	# Keep the patrols out of the way unless a test wants them.
	for coworker in tree.get_nodes_in_group(&"coworkers"):
		coworker.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frames(3)


func _teleport(pos: Vector3, yaw := 0.0) -> void:
	robot.global_position = pos
	robot.rotation.y = yaw
	robot.facing_yaw = yaw
	robot.velocity = Vector3.ZERO
	await physics_frames(3)


func _grow(amount: float) -> void:
	robot.extension_input = signf(amount)
	await seconds(absf(amount) / robot.extension_rate + 0.3)
	robot.extension_input = 0.0


func cleanup() -> void:
	GameState.clearance = 0
	super()


func test_normal_work_is_not_suspicious() -> void:
	await _start()
	check(Offenses.evaluate(robot).is_empty(), "walking around normally is fine")
	var package: Package = load(PACKAGE).instantiate()
	level.add_child(package)
	package.global_position = robot.get_hold_position()
	robot.grab(package)
	await physics_frames(3)
	check(Offenses.evaluate(robot).is_empty(), "carrying normal stock is fine")


func test_offenses() -> void:
	await _start()
	await _grow(2.0)
	check(Offenses.evaluate(robot).has(Offenses.ODD_HEIGHT), "being tall on the open floor is odd")
	await _teleport(Vector3(-12.5, 0.05, 0))
	check(not Offenses.evaluate(robot).has(Offenses.ODD_HEIGHT), "but normal in the storage aisles")
	await _grow(-3.0)
	await _teleport(Vector3(13, 0.05, -12))
	check(Offenses.evaluate(robot).has(Offenses.OFF_LIMITS), "the security office needs clearance 1")
	GameState.clearance = 1
	check(not Offenses.evaluate(robot).has(Offenses.OFF_LIMITS), "with clearance 1 it's allowed")
	var contraband: Package = load(PACKAGE).instantiate()
	contraband.contraband = true
	level.add_child(contraband)
	contraband.global_position = robot.get_hold_position()
	robot.grab(contraband)
	await physics_frames(2)
	check(Offenses.evaluate(robot).has(Offenses.CONTRABAND), "holding contraband is suspicious")
	robot.last_fight_time = Time.get_ticks_msec() / 1000.0
	check(Offenses.evaluate(robot).has(Offenses.FIGHTING), "fighting is suspicious")


func test_camera_sees_offense_in_view_only() -> void:
	await _start()
	var camera: SecurityCamera = level.get_node("Security/OfficeCamera")
	var watcher: Watcher = camera.get_node("Head/Watcher")
	# Inside the office, in front of the camera.
	await _teleport(Vector3(12, 0.05, -10))
	await physics_frames(2)
	check(watcher.sees_target, "the office camera sees the robot inside")
	check(watcher.alarmed, "and it's off limits")
	var before := Suspicion.value
	await seconds(1.0)
	check(Suspicion.value > before + 5.0, "suspicion rises while seen (%.1f)" % Suspicion.value)
	check(Suspicion.is_alarmed(), "the HUD knows you're seen")
	# Outside the office the wall blocks the view.
	await _teleport(Vector3(12, 0.05, 0))
	await physics_frames(2)
	check(not watcher.sees_target, "walls block the camera's view")


func test_suspicion_decays_and_deliveries_help() -> void:
	await _start()
	Suspicion.add(30.0, "test")
	var start := Suspicion.value
	await seconds(1.0)
	check(is_equal_approx(Suspicion.value, start), "no decay right after an offense")
	await seconds(Suspicion.decay_delay + 1.0)
	check(Suspicion.value < start - 1.0, "suspicion decays when nothing happens")
	var before := Suspicion.value
	Quota.record_delivery(null)
	check(Suspicion.value < before - 5.0, "a delivery lowers suspicion")


func test_meter_maxes_once_and_respects_enabled() -> void:
	await _start()
	var maxed := [0]
	Suspicion.maxed.connect(func() -> void: maxed[0] += 1)
	Suspicion.add(150.0, "test")
	Suspicion.add(10.0, "test")
	check(Suspicion.value == Suspicion.MAX, "the meter caps at max")
	check(maxed[0] == 1, "maxed fires once")
	Suspicion.reset()
	Suspicion.enabled = false
	Suspicion.add(50.0, "test")
	check(Suspicion.value == 0.0, "nothing counts while under control")


func test_falling_behind_puts_you_under_review() -> void:
	await _start()
	Quota.expected_interval = 0.2
	await seconds(0.5)
	check(Suspicion.is_under_review(), "two missed deliveries puts you under review")
	Suspicion.add(10.0, "test")
	check(is_equal_approx(Suspicion.value, 15.0), "watchers are more sensitive under review")
	Quota.expected_interval = 0.0
	Quota.record_delivery(null)
	Quota.record_delivery(null)
	check(not Suspicion.is_under_review(), "catching up clears the review")


func test_coworker_reports_only_obvious_things() -> void:
	await _start()
	var coworker: RobotBody = level.get_node("Coworkers/FloorWorker")
	var eyes: Watcher = coworker.get_node("Eyes")
	coworker.process_mode = Node.PROCESS_MODE_INHERIT
	coworker.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	# Stand in front of the coworker (it faces -Z), tall on the open floor.
	await _teleport(coworker.global_position + Vector3(0, 0, -3))
	await _grow(2.0)
	await physics_frames(3)
	check(eyes.sees_target, "the coworker sees you")
	check(not eyes.alarmed, "but doesn't care about being tall")
	check(Suspicion.value < 1.0, "so no report")
	robot.last_fight_time = Time.get_ticks_msec() / 1000.0
	await physics_frames(3)
	check(eyes.alarmed and Suspicion.value >= 19.0, "fighting gets reported (%.1f)" % Suspicion.value)
	var after_report := Suspicion.value
	await seconds(1.0)
	robot.last_fight_time = Time.get_ticks_msec() / 1000.0
	await physics_frames(3)
	check(Suspicion.value <= after_report + 0.1, "one report per cooldown")


func test_camera_sweeps() -> void:
	await _start()
	var head: Node3D = level.get_node("Security/FloorCamera/Head")
	var start := head.rotation.y
	await seconds(1.0)
	check(absf(head.rotation.y - start) > 0.1, "the floor camera sweeps")


func test_coworker_patrols() -> void:
	await _start()
	var coworker: RobotBody = level.get_node("Coworkers/FloorWorker")
	coworker.process_mode = Node.PROCESS_MODE_INHERIT
	var start := coworker.global_position
	# It starts on its first point, waits there, then walks to the next.
	await seconds(coworker.get_node("Brain").wait_time + 1.5)
	check(coworker.global_position.distance_to(start) > 3.0, "coworkers walk their route")
