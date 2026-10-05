extends TestCase
## The warehouse: clearance and scanner checkpoints, both routes to each
## keycard, the end of the slice, item pools, the wheel base (crafting,
## speed, conveyors, the ramp over the sorting pit) and magnetic hands.

const WAREHOUSE := "res://scenes/levels/warehouse.tscn"

var level: Node3D
var robot: RobotBody
var controller: PlayerController
var inventory: Inventory
var hud: Hud


## Starts on the floor with everyone who could interfere switched off,
## except the cameras named in `cameras` (to prove a route is out of view).
func _start(cameras: Array[String] = []) -> void:
	level = load(WAREHOUSE).instantiate()
	level.skip_intro = true
	tree.root.add_child(level)
	_nodes.append(level)
	robot = level.get_node("Player")
	controller = level.get_node("Player/Controller")
	inventory = Inventory.of(robot)
	hud = level.get_node("HUD")
	controller.enabled = false
	level.get_node("Coworkers").process_mode = Node.PROCESS_MODE_DISABLED
	# Guards stand still and see nothing, but can still be hit.
	for guard in level.get_node("Guards").get_children():
		if guard is RobotBody:
			guard.get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
			guard.get_node("Visual/Core/Eyes").process_mode = Node.PROCESS_MODE_DISABLED
	for camera in level.get_node("Security").get_children():
		if not cameras.has(String(camera.name)):
			camera.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frames(3)
	Dialogue.reset()


func _teleport(pos: Vector3, yaw := 0.0) -> void:
	robot.global_position = pos
	robot.rotation.y = yaw
	robot.facing_yaw = yaw
	robot.velocity = Vector3.ZERO
	await physics_frames(3)


## Facing yaw for a direction on the floor.
func _yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _drive(direction: Vector3, time: float) -> void:
	robot.move_input = direction
	robot.facing_yaw = _yaw(direction)
	await seconds(time)
	robot.move_input = Vector3.ZERO


func _resize_to(extension: float, timeout := 2.0) -> void:
	var left := timeout
	robot.extension_input = signf(extension - robot.extension)
	while absf(robot.extension - extension) > 0.1 and left > 0.0:
		await physics_frames(1)
		left -= 1.0 / Engine.physics_ticks_per_second
	robot.extension_input = 0.0
	await physics_frames(3)


func _swing_with(id: StringName) -> String:
	inventory.add(ItemState.new(id))
	inventory.select(inventory.slots.find(inventory.get_items().back()))
	return inventory.use_equipped()


func _recipe_for(result: StringName) -> int:
	for i in ItemCatalog.RECIPES.size():
		if ItemCatalog.RECIPES[i].result == result:
			return i
	return -1


func _card_text() -> String:
	var card: Label = hud.get_node("Card")
	return card.text if card.visible else ""


# --- Clearance and checkpoints ---

func test_clearance_gates_receiving() -> void:
	await _start()
	var gate: Door = level.get_node("Geometry/ReceivingGate")
	await _teleport(Vector3(23, 0.05, 7), _yaw(Vector3.RIGHT))
	await _drive(Vector3.RIGHT, 2.0)
	check(not gate.is_open, "a level 0 badge doesn't open Receiving")
	check(robot.global_position.x < 28.0, "and the gate holds you back")
	check(Suspicion.value > 0.0 and Suspicion.last_reason == "Badge rejected",
		"a rejected badge is a little suspicious")
	await _teleport(Vector3(40, 0.05, 0))
	check(Offenses.evaluate(robot).has(Offenses.OFF_LIMITS),
		"being in Receiving without clearance is off limits")

	await _teleport(Vector3(23, 0.05, 7), _yaw(Vector3.RIGHT))
	GameState.grant_clearance(1)
	await _drive(Vector3.RIGHT, 2.0)
	check(gate.is_open, "a level 1 badge opens it")
	check(robot.global_position.x > 30.0, "and you can walk into Receiving")
	await _teleport(Vector3(40, 0.05, 0))
	check(not Offenses.evaluate(robot).has(Offenses.OFF_LIMITS), "where you're now allowed")
	await seconds(3.0)
	check(not gate.is_open, "the gate closes behind you")
	GameState.grant_clearance(0)
	check(GameState.clearance == 1, "clearance never goes down")


func test_scanner_reads_what_you_carry() -> void:
	await _start()
	GameState.grant_clearance(1)
	var gate: Door = level.get_node("Geometry/ReceivingGate")
	var scanner: ScannerCheckpoint = level.get_node("Checkpoints/ReceivingScanner")
	var cutter := ItemState.new(&"box_cutter")
	inventory.add(cutter)
	inventory.select(-1)
	check(not Inventory.shows_contraband(robot), "a stowed box cutter is out of sight")
	await _teleport(Vector3(23, 0.05, 7), _yaw(Vector3.RIGHT))
	await _drive(Vector3.RIGHT, 0.6)
	check(gate.is_open, "your badge still opens the gate")
	check(Suspicion.value >= scanner.contraband_suspicion * 0.99,
		"but the scanner sees the stowed box cutter (%.1f)" % Suspicion.value)

	inventory.remove(cutter)
	Suspicion.reset()
	await _teleport(Vector3(36, 0.05, 0))
	await seconds(2.5)
	await _teleport(Vector3(23, 0.05, 7), _yaw(Vector3.RIGHT))
	await _drive(Vector3.RIGHT, 0.6)
	check(gate.is_open and Suspicion.value == 0.0, "carrying nothing sharp passes clean")


# --- Level 1 keycard ---

func test_level1_card_by_fighting() -> void:
	await _start()
	var supervisor: RobotBody = level.get_node("Guards/Supervisor")
	var carrier: KeycardCarrier = supervisor.get_node("Keycard")
	var dropped: Array[Item] = []
	carrier.dropped.connect(func(card: Item) -> void: dropped.append(card))
	check(carrier.has_card, "the floor supervisor wears the level 1 card")
	await _teleport(supervisor.global_position + Vector3(0, 0, 1.6), _yaw(Vector3.FORWARD))
	check(_swing_with(&"box_cutter") == "Hit!", "a swing connects")
	check(not carrier.has_card and dropped.size() == 1, "the hit knocks the card loose")
	check(Offenses.evaluate(robot).has(Offenses.FIGHTING), "and it's loud: you're fighting")
	await seconds(1.0)
	inventory.select(-1)
	robot.grab(dropped[0])
	await physics_frames(2)
	check(GameState.clearance == 1, "picking the card up raises your badge to level 1")
	check(robot.held == null and not is_instance_valid(dropped[0]),
		"the card goes into your badge, not your hands")
	check(Dialogue.is_playing(&"elle_receiving"), "Elle points you at Receiving")
	check(_card_text().begins_with("CLEARANCE 1"), "the HUD announces it")


func test_level1_card_by_sneaking() -> void:
	await _start(["HardwareCamera"])
	var door: Door = level.get_node("Geometry/SupervisorDoor")
	await _teleport(Vector3(-7.5, 0.05, -29), _yaw(Vector3.FORWARD))
	await _drive(Vector3.FORWARD, 1.5)
	check(not door.is_open and robot.global_position.z > -32.0,
		"the office door wants level 1")
	Suspicion.reset()

	# The vent behind the lumber rack, out of the camera's sight.
	await _teleport(Vector3(-1.4, 0.05, -38.4), _yaw(Vector3.LEFT))
	await _drive(Vector3.LEFT, 1.2)
	check(robot.global_position.x > -3.0, "at normal height you don't fit through the vent")
	await _resize_to(0.0)
	await _drive(Vector3.LEFT, 1.5)
	check(robot.global_position.x < -4.5, "shrunk down, you squeeze into the office")
	await _resize_to(0.4)
	await _teleport(Vector3(-6.4, 0.05, -37.5), _yaw(Vector3.LEFT))
	var card := robot.find_grab_target()
	check(card is Item and (card as Item).state.id == &"keycard_1", "the spare card is on the desk")
	robot.grab(card)
	await physics_frames(2)
	check(GameState.clearance == 1, "the spare raises your badge to level 1")
	check(Suspicion.value == 0.0, "and nobody saw a thing")
	await _teleport(Vector3(-7.5, 0.05, -33.6), _yaw(Vector3.BACK))
	await physics_frames(5)
	check(door.is_open, "now the office door lets you out")


# --- Level 2 keycard and the end of the slice ---

func test_level2_card_by_fighting_ends_the_slice() -> void:
	await _start()
	GameState.grant_clearance(1)
	var boss: RobotBody = level.get_node("Guards/DockBoss")
	var carrier: KeycardCarrier = boss.get_node("Keycard")
	await _teleport(boss.global_position + Vector3(0, 0, 1.6), _yaw(Vector3.FORWARD))
	# A thrown package works as well as a tool.
	robot.grab(Item.spawn(ItemState.new(&"tape"), level, robot.get_hold_position()))
	await physics_frames(2)
	robot.throw(robot.get_forward() * 10.0 + Vector3.UP)
	await seconds(0.5)
	check(not carrier.has_card, "a hard throw knocks the dock boss's card loose")
	await seconds(1.0)
	var card: Item = null
	for item: Item in tree.get_nodes_in_group(&"items"):
		if item.state.id == &"keycard_2" and item.global_position.distance_to(boss.global_position) < 4.0:
			card = item
	check(card != null, "the level 2 card lands nearby")
	if card == null:
		return
	robot.grab(card)
	await physics_frames(2)
	check(GameState.clearance == 2, "your badge is level 2")
	check(GameState.has_flag(GameState.FLAG_SLICE_COMPLETE), "that's the end of the slice")
	check(_card_text().contains("END OF THE VERTICAL SLICE"), "an end card says so")
	check(Dialogue.is_playing(&"elle_slice_end"), "and Elle signs off")
	check(controller.robot == robot, "you can keep playing afterwards")


func test_level2_card_by_climbing_into_the_office() -> void:
	await _start(["ReceivingCamera"])
	GameState.grant_clearance(1)
	var door: Door = level.get_node("Geometry/RecOfficeDoor")
	await _teleport(Vector3(47, 0.05, 2), _yaw(Vector3.RIGHT))
	await _drive(Vector3.RIGHT, 1.5)
	check(not door.is_open and robot.global_position.x < 50.0,
		"the office door wants level 2")
	Suspicion.reset()

	# Over the north wall, where the camera can't see.
	await _teleport(Vector3(54, 0.05, -3.2), _yaw(Vector3.BACK))
	await _resize_to(2.0)
	robot.arms_input = true
	await seconds(0.5)
	check(robot.is_hooked, "you can hook the top of the office wall")
	robot.extension_input = -1.0
	await seconds(2.0)
	robot.extension_input = 0.0
	robot.arms_input = false
	check(robot.global_position.y > 2.9, "and climb onto it")
	await _drive(Vector3.BACK, 1.0)
	await seconds(0.5)
	check(robot.global_position.z > -1.5 and robot.global_position.y < 0.3,
		"then drop down inside")
	await _resize_to(0.4)
	await _teleport(Vector3(54.4, 0.05, 2), _yaw(Vector3.RIGHT))
	var card := robot.find_grab_target()
	check(card is Item and (card as Item).state.id == &"keycard_2", "the spare card is on the desk")
	robot.grab(card)
	await physics_frames(2)
	check(GameState.clearance == 2, "your badge is level 2")
	check(Suspicion.value == 0.0, "and the camera never saw you climb (%.1f)" % Suspicion.value)
	check(GameState.has_flag(GameState.FLAG_SLICE_COMPLETE), "the slice ends either way")


# --- Story ---

func test_elle_points_you_to_the_level1_card() -> void:
	await _start()
	var radio: Radio = level.get_node("Radio")
	radio.tuned_in.emit()
	await physics_frames(2)
	Dialogue.skip()
	await physics_frames(2)
	check(not GameState.has_flag(GameState.FLAG_KEYCARD_HINT), "no hint during first contact")
	Quota.record_delivery(null)
	check(Dialogue.is_playing(&"elle_back_to_work") and Dialogue.is_playing(&"elle_keycard_hint"),
		"after your first delivery Elle brings up keycards")
	check(GameState.has_flag(GameState.FLAG_KEYCARD_HINT), "the hint is remembered")

	# Without that delivery, walking into Hardware does it too.
	Dialogue.reset()
	GameState.reset_story()
	GameState.set_flag(GameState.FLAG_MET_ELLE)
	await _teleport(Vector3(0, 0.05, -18))
	await physics_frames(3)
	check(Dialogue.is_playing(&"elle_keycard_hint"), "walking into Hardware gets the hint")


# --- Items ---

func test_departments_have_their_own_item_pools() -> void:
	await _start()
	await physics_frames(2)
	var spots := 0
	for spot in level.get_node("Items").get_children():
		if spot is ItemSpot:
			spots += 1
			check(spot.item != null and spot.item.state.id in ItemCatalog.POOLS[spot.pool],
				"%s turned up something from the %s pool" % [spot.name, spot.pool])
	check(spots >= 9, "every department has spots (%d)" % spots)
	for pool: StringName in ItemCatalog.POOLS:
		for id: StringName in ItemCatalog.POOLS[pool]:
			check(ItemCatalog.has(id), "%s: unknown item %s" % [pool, id])
	var receiving: Zone = level.get_node("Zones/Receiving")
	var motor: Item = level.get_node("Items/WheelMotor")
	check(ItemCatalog.is_key_part(motor.state.id) and receiving.contains_point(motor.global_position),
		"the wheel motor, a key part, is in Receiving")
	check(ItemCatalog.POOLS[&"receiving"].has(&"strap"), "Receiving stocks straps")


func test_wheel_base_crafts_and_speeds_you_up() -> void:
	await _start()
	await _teleport(Vector3(-8, 0.05, -10))
	await _drive(Vector3.RIGHT, 1.0)
	var tread_distance := robot.global_position.x + 8.0

	var dock: ChargingDock = level.get_node("Dock")
	for id: StringName in [&"wheel_motor", &"strap", &"tape"]:
		inventory.add(ItemState.new(id))
	var recipe := _recipe_for(&"wheel_base")
	check(GameState.knows_recipe(recipe), "holding the parts reveals the wheel base recipe")
	check(ItemCatalog.RECIPES[recipe].inputs.size() <= 3, "it takes at most 3 items")
	var wheels := dock.craft(recipe, inventory)
	check(wheels != null and wheels.id == &"wheel_base", "the dock crafts a wheel base")
	check(inventory.count(&"wheel_motor") == 0, "using up the parts")
	inventory.select(inventory.slots.find(wheels))
	inventory.use_equipped()
	check(GameState.has_upgrade(&"wheel_base"), "using it installs it")
	await physics_frames(2)
	check(robot.wheels, "your body has wheels now")

	await _teleport(Vector3(-8, 0.05, -10))
	await _drive(Vector3.RIGHT, 1.0)
	var wheel_distance := robot.global_position.x + 8.0
	check(wheel_distance > tread_distance * 1.3,
		"wheels are faster (%.1f m vs %.1f m in a second)" % [wheel_distance, tread_distance])


func test_conveyors_carry_robots_and_packages() -> void:
	await _start()
	await _teleport(Vector3(6, 0.05, -32))
	await seconds(1.0)
	var on_treads := robot.global_position.x - 6.0
	check(on_treads > 1.5 and on_treads < 3.5, "the belt carries you along (%.1f m)" % on_treads)
	GameState.install_upgrade(&"wheel_base")
	await _teleport(Vector3(6, 0.05, -32))
	await seconds(1.0)
	var on_wheels := robot.global_position.x - 6.0
	check(on_wheels > on_treads * 1.8, "on wheels you ride it much faster (%.1f m)" % on_wheels)
	var package: Package = level.get_node("Work/Inbound1")
	check(package.global_position.x < 55.0, "the unload belt carries stock in (x %.1f)"
		% package.global_position.x)


func test_ramp_launches_wheels_over_the_pit() -> void:
	await _start()
	var island_top := 2.5
	# Treads roll up the ramp and drop into the pit.
	await _teleport(Vector3(8, 0.05, -32), _yaw(Vector3.RIGHT))
	await _drive(Vector3.RIGHT, 3.0)
	check(not robot.is_launched and robot.global_position.y < 0.0,
		"without wheels you fall into the pit (y %.1f)" % robot.global_position.y)
	# Too tall to climb out onto the island.
	await _teleport(Vector3(19, -4.95, -32.5), _yaw(Vector3.RIGHT))
	await _resize_to(5.0)
	robot.arms_input = true
	await seconds(0.5)
	check(not robot.is_hooked, "the island is too tall to climb from the pit")
	robot.arms_input = false
	await _resize_to(0.4)

	GameState.install_upgrade(&"wheel_base")
	await _teleport(Vector3(8, 0.05, -32), _yaw(Vector3.RIGHT))
	var launched := [false]
	robot.launched.connect(func() -> void: launched[0] = true)
	await _drive(Vector3.RIGHT, 2.5)
	check(launched[0], "on wheels the ramp launches you")
	check(robot.global_position.y > island_top - 0.1 and robot.global_position.x > 20.5,
		"onto the island (%s)" % robot.global_position)
	var coil: Item = level.get_node("Items/IslandCoil")
	check(coil.global_position.distance_to(robot.global_position) < 5.0,
		"where the electromagnet coil was waiting")


func test_magnetic_hands_climb_metal_shelving() -> void:
	await _start()
	await _teleport(Vector3(38, 0.05, 2.8), _yaw(Vector3.FORWARD))
	robot.arms_input = true
	await seconds(0.5)
	check(not robot.is_hooked, "without magnetic hands the 7.5 m racking has nothing to grab")
	robot.arms_input = false
	await seconds(0.3)

	GameState.install_upgrade(&"magnetic_hands")
	await physics_frames(2)
	check(robot.magnetic_hands and robot.is_metal_in_reach(), "magnetic hands find the metal")
	robot.arms_input = true
	await seconds(0.4)
	check(robot.is_hooked and robot.is_clinging, "and stick to it")
	robot.extension_input = 1.0
	var left := 5.0
	while robot.is_clinging and left > 0.0:
		await physics_frames(6)
		left -= 0.1
	check(robot.is_hooked and not robot.is_clinging, "growing climbs until the top is in reach")
	robot.extension_input = -1.0
	await seconds(2.0)
	robot.extension_input = 0.0
	robot.arms_input = false
	await seconds(0.3)
	check_near(robot.global_position.y, 7.5, 0.15, "then you pull yourself up on top")
	var overstock: Item = level.get_node("Items/OverstockId")
	check(overstock.global_position.distance_to(robot.global_position) < 2.0,
		"where the overstock was out of everyone else's reach")
