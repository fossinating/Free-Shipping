extends TestCase
## Movement, growing and shrinking, arms, and climbing in the test room.

const ROOM := "res://scenes/world/test_room.tscn"
const ROBOT := "res://scenes/robot/robot.tscn"

var room: Node3D


func _spawn_robot(pos: Vector3, yaw := 0.0, start_extension := 0.4) -> RobotBody:
	room = spawn(ROOM)
	var robot: RobotBody = load(ROBOT).instantiate()
	robot.start_extension = start_extension
	robot.position = pos
	robot.rotation.y = yaw
	room.add_child(robot)
	await physics_frames(2)
	return robot


func test_player_walks_with_input() -> void:
	room = spawn(ROOM)
	var player: RobotBody = room.get_node("Player")
	await physics_frames(5)
	var start := player.global_position
	Input.action_press("move_forward")
	await seconds(1.0)
	check(start.z - player.global_position.z > 3.0, "player should walk forward")
	check(player.is_on_floor(), "player should stay on the floor")


func test_grow_and_shrink_ease_within_limits() -> void:
	var robot := await _spawn_robot(Vector3(0, 0.05, 10))
	robot.extension_input = 1.0
	await seconds(0.4)
	check(robot.extension > 2.0, "growing for 0.4s should add over 2m (was %.2f)" % robot.extension)
	await seconds(1.5)
	check_near(robot.extension, robot.max_extension, 0.01, "growth stops at max")
	robot.extension_input = -1.0
	await seconds(1.5)
	check_near(robot.extension, 0.0, 0.01, "shrinking stops at zero")
	check(robot.is_on_floor(), "robot stays grounded while resizing")


func test_cannot_grow_through_ceiling() -> void:
	# Under the vent's top, which starts 1.6 m up.
	var robot := await _spawn_robot(Vector3(-11, 0.05, 6), 0.0, 0.0)
	robot.extension_input = 1.0
	await seconds(1.0)
	check(robot.get_height() < 1.62, "height should stop under the vent (was %.2f)" % robot.get_height())


func test_vent_needs_shrinking() -> void:
	var robot := await _spawn_robot(Vector3(-11, 0.05, 9))
	robot.move_input = Vector3.FORWARD
	await seconds(1.5)
	check(robot.global_position.z > 6.0, "a normal-height robot is blocked by the vent")
	robot.extension_input = -1.0
	await seconds(1.0)
	check(robot.global_position.z < 5.0, "a shrunk robot fits through the vent")


func test_arms_stop_at_walls() -> void:
	var robot := await _spawn_robot(Vector3(0, 0.05, 18.5), PI)
	robot.arms_input = true
	await seconds(0.5)
	# Facing +Z, the south wall face is 1.5 m from the center.
	check(robot.arm_extension < 1.0, "arms should stop at the wall (was %.2f)" % robot.arm_extension)
	robot.arms_input = false
	await seconds(0.5)
	check(robot.arm_extension < 0.05, "arms retract when released")


func test_climb_crate() -> void:
	var robot := await _spawn_robot(Vector3(-6, 0.05, -3.5))
	robot.arms_input = true
	await seconds(0.5)
	check(robot.is_hooked, "extending arms at the crate should hook its edge")
	robot.extension_input = -1.0
	await seconds(1.5)
	check(not robot.is_hooked and not robot.is_mantling, "should finish climbing")
	check_near(robot.global_position.y, 1.0, 0.1, "should stand on the crate")
	check(robot.global_position.z < -5.0, "should be on top of the crate, not in front of it")


func test_climb_high_shelf() -> void:
	var robot := await _spawn_robot(Vector3(11, 0.05, -5))
	robot.extension_input = 1.0
	await seconds(1.5)
	robot.extension_input = 0.0
	robot.arms_input = true
	await seconds(0.5)
	check(robot.is_hooked, "a fully grown robot should hook the 6 m shelf")
	robot.extension_input = -1.0
	await seconds(2.5)
	check_near(robot.global_position.y, 6.0, 0.1, "should stand on the high shelf")


func test_too_short_to_hook_high_shelf() -> void:
	var robot := await _spawn_robot(Vector3(11, 0.05, -5))
	robot.arms_input = true
	await seconds(0.5)
	check(not robot.is_hooked, "the 6 m shelf is out of reach at normal height")


func test_letting_go_drops() -> void:
	var robot := await _spawn_robot(Vector3(5, 0.05, -5))
	robot.extension_input = 1.0
	await seconds(0.45)
	robot.extension_input = 0.0
	await seconds(0.3)
	robot.arms_input = true
	await seconds(0.5)
	check(robot.is_hooked, "should hook the 4 m shelf at about 4 m tall")
	robot.extension_input = -1.0
	await seconds(0.3)
	var hanging_y := robot.global_position.y
	check(hanging_y > 0.5, "shrinking while hooked lifts the treads")
	robot.extension_input = 0.0
	robot.arms_input = false
	await seconds(1.0)
	check(not robot.is_hooked, "releasing the arms lets go")
	check(robot.is_on_floor() and robot.global_position.y < 0.1, "robot falls back to the floor")


func test_press_high_button() -> void:
	var robot := await _spawn_robot(Vector3(8, 0.05, 3.5), PI, 4.0)
	var button: PushButton = room.get_node("Geometry/HighButton")
	robot.move_input = Vector3.BACK
	await seconds(1.0)
	check(button.is_pressed, "the core should press the high button")


func test_short_robot_cannot_press_high_button() -> void:
	var robot := await _spawn_robot(Vector3(8, 0.05, 3.5), PI)
	var button: PushButton = room.get_node("Geometry/HighButton")
	robot.move_input = Vector3.BACK
	await seconds(1.0)
	check(not button.is_pressed, "a normal-height robot can't reach the high button")


func _give_package(robot: RobotBody) -> Package:
	var package: Package = load("res://scenes/work/package.tscn").instantiate()
	room.add_child(package)
	package.global_position = robot.get_hold_position()
	robot.grab(package)
	await physics_frames(2)
	return package


func test_shrunk_set_down_at_a_chute_keeps_the_robot_on_the_floor() -> void:
	# Fully shrunk behind the chute at (16, 0, 4): the hold spot is inside
	# the bin's back wall (GH #10).
	var robot := await _spawn_robot(Vector3(16, 0.05, 5.33), 0.0, 0.0)
	var package := await _give_package(robot)
	check(not robot.drop(), "there's no room to set it down against the bin")
	check(robot.held == package, "so the robot keeps holding it")
	await seconds(1.0)
	check(robot.global_position.y > -0.05 and robot.is_on_floor(),
		"the robot stays on the floor (y %.2f)" % robot.global_position.y)
	# Tall enough to clear the rim, it goes in.
	var received := [0]
	(room.get_node("Work/AnyChute") as Chute).received.connect(
		func(_p: Package) -> void: received[0] += 1)
	robot.extension_input = 1.0
	await seconds(0.15)
	robot.extension_input = 0.0
	await seconds(0.3)
	check(robot.drop(), "grown, it can set the package down")
	await seconds(1.0)
	check(received[0] == 1, "into the chute")
	check(robot.global_position.y > -0.05, "and still stands on the floor")


func test_set_down_against_a_wall_stays_in_the_room() -> void:
	# Flush against the south wall (its face at z 20), at several heights (GH #11).
	for start_extension in [0.0, 0.2, 0.4, 1.0]:
		var robot := await _spawn_robot(Vector3(0, 0.05, 19.47), PI, start_extension)
		var package := await _give_package(robot)
		var dropped := robot.drop()
		await seconds(1.0)
		if dropped:
			check(package.global_position.z < 20.0 and package.global_position.y > 0.0,
				"set down at %.1f, the package stays in the room (at %s)"
				% [start_extension, package.global_position])
		else:
			check(robot.held == package, "or the robot keeps holding it at %.1f" % start_extension)
		room.queue_free()
		await physics_frames(2)


func test_turning_keeps_the_scale_exact() -> void:
	# Driving in circles while carrying (GH #14). The old drift broke the
	# held package's basis within about 15 s.
	var robot := await _spawn_robot(Vector3(0, 0.05, 10))
	await _give_package(robot)
	for i in 900:
		var yaw := wrapf(i * 0.05, -PI, PI)
		robot.facing_yaw = yaw
		robot.move_input = Basis(Vector3.UP, yaw) * Vector3.FORWARD * 0.3
		await tree.physics_frame
	robot.move_input = Vector3.ZERO
	var drift := (robot.scale - Vector3.ONE).abs()
	check(maxf(drift.x, maxf(drift.y, drift.z)) < 1e-6, "scale stays 1 (was %s)" % robot.scale)


func test_falling_out_of_the_level_puts_the_robot_back() -> void:
	var robot := await _spawn_robot(Vector3(0, 0.05, 10))
	await seconds(1.2)
	robot.global_position = Vector3(0, RobotBody.FALL_LIMIT - 1.0, 10)
	await physics_frames(2)
	check(robot.global_position.y > -0.1 and robot.global_position.y < 1.0,
		"back where it stood (at %s)" % robot.global_position)


func test_full_strength_throws_dont_tunnel_through_walls() -> void:
	# GH #11: thrown packages went through walls. A thin partition 2 m in
	# front of the robot, hit at full throw speed from several heights.
	for start_extension in [0.0, 0.4, 1.0]:
		var robot := await _spawn_robot(Vector3(0, 0.05, 15), PI, start_extension)
		var partition := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6, 8, 0.1)
		shape.shape = box
		partition.add_child(shape)
		room.add_child(partition)
		partition.global_position = Vector3(0, 4, 17)
		var package := await _give_package(robot)
		check(robot.throw(Vector3(0, 1.0, 14.0)), "the throw leaves the hand")
		await seconds(1.5)
		check(package.global_position.z < 17.0,
			"thrown at %.1f, the package bounces off the partition (at %s)"
			% [start_extension, package.global_position])
		room.queue_free()
		await physics_frames(2)
