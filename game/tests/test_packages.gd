extends TestCase
## Grabbing, carrying, throwing and delivering packages.

const ROOM := "res://scenes/world/test_room.tscn"
const ROBOT := "res://scenes/robot/robot.tscn"
const PACKAGE := "res://scenes/work/package.tscn"

var room: Node3D


func _setup(robot_pos: Vector3, yaw := 0.0, start_extension := 0.4) -> RobotBody:
	room = spawn(ROOM)
	var robot: RobotBody = load(ROBOT).instantiate()
	robot.start_extension = start_extension
	robot.position = robot_pos
	robot.rotation.y = yaw
	room.add_child(robot)
	await physics_frames(2)
	return robot


func _package(pos: Vector3, destination := &"") -> Package:
	var package: Package = load(PACKAGE).instantiate()
	package.destination = destination
	package.position = pos
	room.add_child(package)
	return package


## Launch velocity that lands at `to` when thrown from `from` at 45 degrees.
func _lob(from: Vector3, to: Vector3) -> Vector3:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var distance := flat.length()
	var rise := to.y - from.y
	var speed := sqrt(gravity * distance * distance / (distance - rise))
	return (flat.normalized() + Vector3.UP).normalized() * speed


func test_grab_and_carry() -> void:
	var robot := await _setup(Vector3(-10, 0.05, -12))
	var package := _package(Vector3(-10, 0.3, -14))
	await seconds(0.3)
	check(robot.find_grab_target() == package, "the package in front should be the grab target")
	robot.grab(package)
	await seconds(0.3)
	check(package.is_held(), "package should be held")
	check(package.global_position.distance_to(robot.get_hold_position()) < 0.1,
		"package should be pulled into the hands")
	robot.move_input = Vector3.RIGHT
	await seconds(1.0)
	check(package.global_position.distance_to(robot.get_hold_position()) < 0.3,
		"package should follow the robot")


func test_grab_range() -> void:
	var robot := await _setup(Vector3(-10, 0.05, -12))
	var behind := _package(Vector3(-10, 0.3, -10.5))
	var far := _package(Vector3(-10, 0.3, -16))
	await seconds(0.3)
	check(robot.find_grab_target() == null, "packages behind or far away can't be grabbed")
	behind.queue_free()
	far.queue_free()
	_package(Vector3(-10.8, 0.3, -13.6))
	await seconds(0.3)
	check(robot.find_grab_target() != null, "a package off to the side but in reach can be grabbed")


func test_tall_robot_cannot_reach_floor() -> void:
	var robot := await _setup(Vector3(-10, 0.05, -12), 0.0, 4.0)
	_package(Vector3(-10, 0.3, -13.5))
	await seconds(0.3)
	check(robot.find_grab_target() == null, "a tall robot can't reach the floor")


func test_grow_to_grab_from_shelf() -> void:
	var robot := await _setup(Vector3(5, 0.05, -6.2))
	var package := _package(Vector3(5, 4.3, -7.5))
	await seconds(0.5)
	check(robot.find_grab_target() == null, "the shelf top is out of reach at normal height")
	robot.extension_input = 1.0
	await seconds(0.4)
	robot.extension_input = 0.0
	await seconds(0.3)
	check(robot.find_grab_target() == package,
		"growing brings the shelf package in reach (core at %.2f)" % robot.get_core_position().y)


func test_drop_sets_package_down() -> void:
	var robot := await _setup(Vector3(-10, 0.05, -12))
	var package := _package(Vector3(-10, 0.3, -13.5))
	await seconds(0.3)
	robot.grab(package)
	await seconds(0.3)
	robot.drop()
	await seconds(1.0)
	check(not package.is_held(), "package should be let go")
	check(package.global_position.y < 0.4, "package should land on the floor")
	check(package.global_position.z < -12.5, "package should land in front of the robot")


func test_deliver_into_chute() -> void:
	var robot := await _setup(Vector3(16, 0.05, 6.5), 0.0, 0.8)
	var package := _package(Vector3(16, 0.3, 5.6))
	await seconds(0.3)
	robot.grab(package)
	robot.move_input = Vector3.FORWARD
	await seconds(0.6)
	robot.move_input = Vector3.ZERO
	robot.drop()
	await seconds(1.0)
	check(Quota.delivered_count == 1, "package should be delivered (%d)" % Quota.delivered_count)
	check(not is_instance_valid(package), "delivered package should be removed")


func test_throw_over_railing_into_sorted_chute() -> void:
	var robot := await _setup(Vector3(12, 0.05, 12), PI)
	var package := _package(Vector3(12, 0.3, 13), &"red")
	await seconds(0.3)
	robot.grab(package)
	await seconds(0.3)
	var target := Vector3(12, 1.0, 17)
	var velocity := _lob(robot.get_hold_position(), target)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var arc := ThrowArc.predict(robot.get_world_3d().direct_space_state,
		robot.get_hold_position(), velocity, Vector3.DOWN * gravity,
		[robot.get_rid(), package.get_rid()])
	var landing := arc[arc.size() - 1]
	check(Vector2(landing.x - 12, landing.z - 17).length() < 0.8,
		"the arc preview should end at the chute (ended at %s)" % landing)
	robot.throw(velocity)
	await seconds(2.0)
	check(Quota.delivered_count == 1, "the thrown package should be delivered")
	check(Quota.missort_count == 0, "it was the right chute")


func test_wrong_chute_rejects() -> void:
	var robot := await _setup(Vector3(12, 0.05, 12), PI)
	var package := _package(Vector3(12, 0.3, 13), &"blue")
	await seconds(0.3)
	robot.grab(package)
	await seconds(0.3)
	robot.throw(_lob(robot.get_hold_position(), Vector3(12, 1.0, 17)))
	await seconds(2.0)
	check(Quota.delivered_count == 0, "a blue package doesn't count in the red chute")
	check(Quota.missort_count == 1, "it should count as a missort")
	check(is_instance_valid(package), "the package is spat back out, not destroyed")


func test_walking_nudges_packages() -> void:
	var robot := await _setup(Vector3(-10, 0.05, -12))
	var package := _package(Vector3(-10, 0.3, -14))
	await seconds(0.5)
	var start := package.global_position
	robot.move_input = Vector3.FORWARD
	await seconds(1.0)
	var moved := start.distance_to(package.global_position)
	check(moved > 0.2, "walking into a package should push it")
	check(package.global_position.y < 1.0, "pushing shouldn't launch it (y %.2f)" % package.global_position.y)


func test_player_tap_drops_and_hold_throws() -> void:
	room = spawn(ROOM)
	var player: RobotBody = room.get_node("Player")
	var arc: ThrowArc = room.get_node("Player/ThrowArc")
	await physics_frames(5)
	var package := _package(player.global_position + Vector3(0, 0.3, -1.5))
	await seconds(0.4)
	Input.action_press("interact")
	await physics_frames(2)
	Input.action_release("interact")
	await seconds(0.3)
	check(player.held == package, "clicking should grab the package")
	Input.action_press("interact")
	await physics_frames(3)
	Input.action_release("interact")
	await physics_frames(2)
	check(player.held == null, "a quick click should set it down")
	await seconds(0.8)
	Input.action_press("interact")
	await physics_frames(2)
	Input.action_release("interact")
	await seconds(0.3)
	check(player.held == package, "grab it again")
	Input.action_press("interact")
	await seconds(0.6)
	check(arc.visible, "holding should show the throw arc")
	Input.action_release("interact")
	await physics_frames(2)
	check(player.held == null and not arc.visible, "releasing should throw and hide the arc")
	check(package.linear_velocity.length() > 5.0, "the package should fly")
