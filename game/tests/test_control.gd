extends TestCase
## Control mode: the three opening shifts and the accident.

const OPENING := "res://scenes/levels/opening.tscn"

var level: Node3D
var program: ControlProgram
var robot: RobotBody


func _start(first_shift := -1) -> void:
	level = load(OPENING).instantiate()
	level.debug_start_shift = first_shift
	tree.root.add_child(level)
	_nodes.append(level)
	program = level.get_node("Program")
	robot = level.get_node("Player")
	await physics_frames(3)


## Stops reading real input so the test can drive the robot directly.
func _take_controls() -> void:
	(level.get_node("Player/Controller") as PlayerController).enabled = false


func _teleport(pos: Vector3, yaw := 0.0) -> void:
	robot.global_position = pos
	robot.rotation.y = yaw
	robot.facing_yaw = yaw
	robot.velocity = Vector3.ZERO
	await physics_frames(3)


func _package_from(source_path: String) -> Package:
	var source := level.get_node(source_path)
	for package: Package in tree.get_nodes_in_group(&"packages"):
		if package.source == source and not package.is_held():
			return package
	return null


## Drops a package into a chute's intake, as if it had been thrown there.
func _deliver(package: Package, chute_path: String) -> void:
	var chute: Node3D = level.get_node(chute_path)
	if package.is_held():
		robot.drop()
	package.global_position = chute.global_position + Vector3.UP * 1.2
	package.linear_velocity = Vector3.ZERO
	await seconds(0.3)


func test_shift_one_runs_in_order() -> void:
	await _start()
	check(program.active, "control mode starts active")
	check(program.current_shift.title == "Shift 1", "starts on shift 1")
	check(Quota.target == 4, "shift 1 sets the quota")
	check(program.current_step.name == "Report", "first task is reporting to Station A")

	await _teleport(Vector3(-8, 0.05, 20.5))
	check(program.current_step.name == "Pick", "reaching Station A moves on")

	var stray: Package = load("res://scenes/work/package.tscn").instantiate()
	level.add_child(stray)
	check(not program.can_grab(stray), "packages from elsewhere aren't assigned")
	var package := _package_from("Work/StationA")
	check(program.can_grab(package), "Station A packages are assigned")
	robot.grab(package)
	await physics_frames(3)
	check(program.current_step.name == "Deliver", "grabbing moves on to delivery")

	await _teleport(Vector3(8, 0.05, 19.4))
	await seconds(0.3)
	robot.drop()
	await seconds(1.0)
	check(Quota.delivered_count == 1, "setting it in the chute delivers it")
	check(program.current_step.name == "Quota", "then the quota task starts")

	for i in 3:
		await _deliver(_package_from("Work/StationA"), "Work/Chute1")
		await seconds(1.2)
	check(program.current_shift.title == "Shift 1" and program.current_step == null,
		"shift 1 finishes after the quota")
	await seconds(3.5)
	check(program.current_shift.title == "Shift 2", "shift 2 starts after the break")


func test_route_keeps_robot_on_task() -> void:
	await _start()
	var denials: Array[String] = []
	program.denied.connect(func(reason: String) -> void: denials.append(reason))
	# The route runs from the start (0, 26) to Station A (-8, 20.5).
	var along := (Vector3(-8, 0, 20.5) - Vector3(0, 0, 26)).normalized()
	var across := along.cross(Vector3.UP)
	var at_edge := Vector3(0, 0.05, 26) + along * 3.0 + across * 1.4
	await _teleport(at_edge)
	var filtered := program.filter_move(across)
	check(filtered.dot(across) < 0.05, "moving off the route is blocked")
	check(not denials.is_empty(), "and the player is told why")
	var forward := program.filter_move(along)
	check(forward.dot(along) > 0.9, "moving along the route is fine")


func test_permissions_per_shift() -> void:
	await _start()
	check(not program.filter_arms(true), "arms are locked in shift 1")
	check(not program.allows_throw(), "throwing is locked in shift 1")
	_take_controls()
	robot.extension_input = 1.0
	await seconds(0.5)
	check(robot.extension <= 0.41, "height is locked at company standard in shift 1")
	robot.extension_input = 0.0

	program.release()
	check(program.filter_arms(true) and program.allows_throw(), "release lifts every lock")
	robot.extension_input = 1.0
	await seconds(0.5)
	check(robot.extension > 2.0, "and the robot can grow again")


func test_shift_two_grow_shrink_and_lift() -> void:
	await _start(1)
	check(program.current_shift.title == "Shift 2", "debug start skips to shift 2")
	_take_controls()
	await _teleport(Vector3(-20, 0.05, 2.5), 0.0)
	check(program.current_step.name == "Pick", "at the shelf")
	await _teleport(Vector3(-20, 0.05, 1.3), 0.0)
	robot.extension_input = 1.0
	await seconds(0.5)
	robot.extension_input = 0.0
	check(robot.extension > 2.0 and robot.extension <= 3.01, "growing is allowed up to 3 m")
	await seconds(0.3)
	var package := robot.find_grab_target()
	check(package != null and program.can_grab(package), "a tall robot reaches the top shelf")
	robot.grab(package)
	await physics_frames(3)
	check(program.current_step.name == "UnderConveyor", "then go under the conveyor")

	var door: Door = level.get_node("Geometry/LiftDoor")
	var closed_y := door.position.y
	var button: PushButton = level.get_node("Geometry/LiftButton")
	button._press()
	await seconds(1.5)
	check(door.is_open and door.position.y > closed_y + 3.0, "the lift button opens the door")


func test_shift_three_ends_in_accident() -> void:
	await _start(2)
	var accidents := [0]
	program.accident.connect(func() -> void: accidents[0] += 1)
	await _teleport(Vector3(3, 0.05, -6.5))
	check(program.current_step.name == "Pick", "at the sorting station")
	check(program.filter_arms(true), "arms are allowed for sorting")
	var package := _package_from("Work/SortingLine")
	robot.grab(package)
	await physics_frames(3)
	check(program.current_step.name == "Sort" and program.allows_throw(), "now sort by throwing")

	var sorted := 0
	while sorted < 3:
		package = robot.held if robot.held else _package_from("Work/SortingLine")
		if package == null:
			await seconds(1.0)
			continue
		var chute := "Work/RedChute" if package.destination == &"red" else "Work/BlueChute"
		await _deliver(package, chute)
		sorted += 1
	await seconds(0.3)
	check(program.current_step.name == "Reroute", "after sorting, the route changes")

	await _teleport(Vector3(22, 0.05, -6))
	check(accidents[0] == 1, "walking through the puddle causes the accident")
	check(not program.active, "control mode is over")
	var controller: PlayerController = level.get_node("Player/Controller")
	check(not controller.enabled, "controls are taken away during the shock")
	await seconds(6.0)
	check(controller.enabled, "and come back afterwards")
