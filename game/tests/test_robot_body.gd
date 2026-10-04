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
