extends TestCase
## Items: inventory, contraband, fighting, durability, disguises, the dock
## stash, crafting and upgrades.

const LEVEL := "res://scenes/levels/item_test.tscn"
const PACKAGE := "res://scenes/work/package.tscn"

var level: Node3D
var robot: RobotBody
var inventory: Inventory
var controller: PlayerController


func _start(player_input := false) -> void:
	level = spawn(LEVEL)
	robot = level.get_node("Player")
	inventory = Inventory.of(robot)
	controller = level.get_node("Player/Controller")
	controller.enabled = player_input
	for node in tree.get_nodes_in_group(&"coworkers"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for camera in level.get_node("Security").get_children():
		camera.process_mode = Node.PROCESS_MODE_DISABLED
	_guard().get_node("Brain").process_mode = Node.PROCESS_MODE_DISABLED
	_guard().get_node("Visual/Core/Eyes").process_mode = Node.PROCESS_MODE_DISABLED
	await seconds(0.3)


func _teleport(body: RobotBody, pos: Vector3, yaw := 0.0) -> void:
	body.global_position = pos
	body.rotation.y = yaw
	body.facing_yaw = yaw
	body.velocity = Vector3.ZERO
	await physics_frames(3)


func _guard() -> RobotBody:
	return level.get_node("Guards/FloorGuard")


func _item(id: StringName, pos: Vector3) -> Item:
	return Item.spawn(ItemState.new(id), level, pos)


func _give(id: StringName) -> ItemState:
	var state := ItemState.new(id)
	inventory.add(state)
	return state


func _equip(state: ItemState) -> void:
	inventory.select(inventory.slots.find(state))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _only(list: Array, value: Variant) -> bool:
	return list.size() == 1 and list[0] == value


func _press(action: String) -> void:
	Input.action_press(action)
	await physics_frames(2)
	Input.action_release(action)
	await physics_frames(2)


func test_grab_stow_and_take_out() -> void:
	await _start()
	await _teleport(robot, Vector3(-4, 0.05, 8))
	var item := _item(&"box_cutter", Vector3(-4, 0.3, 7))
	await seconds(0.3)
	check(robot.find_grab_target() == item, "items can be grabbed like packages")
	robot.grab(item)
	check(GameState.held_items.has(&"box_cutter"), "holding an item is remembered")
	var state := item.state
	check(inventory.stow_held(), "a held item can be stowed")
	await physics_frames(2)
	check(robot.held == null and not is_instance_valid(item), "stowing takes it out of the world")
	check(inventory.slots[0] == state, "and puts it in the first slot")
	inventory.select(0)
	check(inventory.take_out(), "the equipped item can be taken out")
	check(robot.held is Item and (robot.held as Item).state == state,
		"into the hands, keeping its state")
	check(inventory.get_items().is_empty(), "leaving the slot empty")


func test_packages_do_not_fit_and_inventory_fills() -> void:
	await _start()
	await _teleport(robot, Vector3(-4, 0.05, 8))
	var package: Package = load(PACKAGE).instantiate()
	level.add_child(package)
	package.global_position = Vector3(-4, 0.3, 7)
	await seconds(0.3)
	robot.grab(package)
	var messages: Array[String] = []
	inventory.message.connect(func(text: String) -> void: messages.append(text))
	check(not inventory.stow_held(), "packages can't be stowed")
	robot.drop()
	for i in Inventory.SLOT_COUNT:
		check(inventory.add(ItemState.new(&"tape")), "slot %d takes an item" % i)
	check(inventory.is_full() and not inventory.add(ItemState.new(&"tape")), "only four slots")
	var item := _item(&"magnet", robot.get_hold_position())
	robot.grab(item)
	check(not inventory.stow_held() and robot.held == item, "a full inventory refuses items")
	check(messages.has("Inventory full"), "and says so")
	inventory.select(-1)
	for expected in [0, 1, 2, 3, -1]:
		inventory.cycle()
		check(inventory.selected == expected, "cycling goes through every slot and holstered")


func test_equipped_tool_is_contraband() -> void:
	await _start()
	await _teleport(robot, Vector3(-4, 0.05, 8))
	var cutter := _give(&"box_cutter")
	var tape := _give(&"tape")
	check(not Offenses.evaluate(robot).has(Offenses.CONTRABAND), "a holstered tool is hidden")
	_equip(cutter)
	check(Offenses.evaluate(robot).has(Offenses.CONTRABAND), "an equipped tool is in plain sight")
	_equip(tape)
	check(not Offenses.evaluate(robot).has(Offenses.CONTRABAND), "tape is harmless")
	var item := _item(&"box_cutter", robot.get_hold_position())
	robot.grab(item)
	check(Offenses.evaluate(robot).has(Offenses.CONTRABAND), "so is holding one")
	check(not Security.is_blending_in(robot), "carrying an item isn't blending in")


func test_swing_knocks_back_and_stuns() -> void:
	await _start()
	var guard := _guard()
	await _teleport(robot, Vector3(-4, 0.05, 8))
	await _teleport(guard, Vector3(-4, 0.05, 6.6), PI)
	var cutter := _give(&"box_cutter")
	_equip(cutter)
	var before := guard.global_position
	inventory.use_equipped()
	check(guard.is_stunned(), "the guard is stunned")
	check(_now() - guard.last_fight_time < 0.5 and _now() - robot.last_fight_time < 0.5,
		"both robots are fighting")
	check(Offenses.evaluate(robot).has(Offenses.FIGHTING), "which is suspicious")
	check(cutter.durability == 5, "swinging costs durability (%d)" % cutter.durability)
	inventory.use_equipped()
	check(cutter.durability == 5, "swings have a cooldown")
	guard.move_input = Vector3(0, 0, 1)
	await seconds(0.6)
	check(guard.global_position.z < before.z - 0.7,
		"the guard is knocked back, not walking (%s)" % guard.global_position)
	await seconds(1.5)
	check(not guard.is_stunned(), "the stun wears off")


func test_thrown_items_and_packages_hurt() -> void:
	await _start()
	var guard := _guard()
	await _teleport(guard, Vector3(-4, 0.05, 4), PI)
	await _teleport(robot, Vector3(-4, 0.05, 8))
	var item := _item(&"box_cutter", robot.get_hold_position())
	robot.grab(item)
	await physics_frames(2)
	robot.throw(Vector3(0, 1.5, -11))
	await seconds(0.8)
	check(guard.is_stunned() or _now() - guard.last_fight_time < 1.0, "a thrown tool hits the guard")
	check(_now() - robot.last_fight_time < 1.0, "and counts as the thrower fighting")
	check(item.state.durability == 5, "a hit wears the tool")
	await seconds(2.5)
	await _teleport(guard, Vector3(-4, 0.05, 4), PI)
	guard.last_fight_time = -INF
	var package: Package = load(PACKAGE).instantiate()
	level.add_child(package)
	package.global_position = robot.get_hold_position()
	robot.grab(package)
	await physics_frames(2)
	robot.throw(Vector3(0, 1.5, -11))
	await seconds(0.8)
	check(_now() - guard.last_fight_time < 1.0, "so does a thrown package")
	await _teleport(guard, Vector3(-4, 0.05, 6.5), PI)
	guard.last_fight_time = -INF
	var dropped := _item(&"tape", robot.get_hold_position())
	robot.grab(dropped)
	robot.drop()
	await seconds(0.5)
	check(guard.last_fight_time == -INF, "setting something down hurts nobody")


func test_stunned_robot_cannot_move() -> void:
	await _start()
	await _teleport(robot, Vector3(-4, 0.05, 8))
	robot.knock_back(Vector3.ZERO, 0.8)
	robot.move_input = Vector3(1, 0, 0)
	await seconds(0.5)
	check(absf(robot.velocity.x) < 0.1, "a stunned robot can't move")
	await seconds(0.6)
	check(robot.velocity.x > 1.0, "and moves again once it recovers")


func test_tools_break_and_repair_at_dock() -> void:
	await _start()
	var dock: ChargingDock = level.get_node("Dock")
	var cutter := _give(&"box_cutter")
	_equip(cutter)
	cutter.durability = 1
	inventory.use_equipped()
	check(cutter.is_broken(), "a tool breaks at 0 durability")
	await seconds(0.6)
	check(inventory.use_equipped().contains("broken") and cutter.durability == 0,
		"a broken tool can't be swung")
	check(not dock.repair(cutter, inventory), "repairs need tape")
	var tape := ItemState.new(&"tape")
	dock.stash.append(tape)
	check(dock.repair(cutter, inventory), "with tape in the stash it can be repaired")
	check(cutter.durability == cutter.get_max_durability(), "back to full durability")
	check(not dock.stash.has(tape), "using up the tape")
	check(not dock.repair(cutter, inventory), "a tool at full durability needs no repair")


func test_scanner_spoofer_fakes_deliveries() -> void:
	await _start()
	Suspicion.set_value(50.0)
	var spoofer := _give(&"scanner_spoofer")
	_equip(spoofer)
	inventory.use_equipped()
	check(Quota.delivered_count == 1, "the spoofer logs a delivery")
	check(Suspicion.value < 50.0, "which lowers suspicion like a real one")
	check(spoofer.uses == 2, "using a charge")
	check(not Offenses.evaluate(robot).has(Offenses.CONTRABAND), "disguises aren't contraband")
	inventory.use_equipped()
	inventory.use_equipped()
	check(Quota.delivered_count == 3, "three charges")
	check(inventory.get_items().is_empty(), "then it's used up")


func test_fake_id_raises_clearance() -> void:
	await _start()
	await _teleport(robot, Vector3(11.5, 0.05, -8))
	check(Offenses.evaluate(robot).has(Offenses.OFF_LIMITS), "the records room needs clearance 1")
	_equip(_give(&"fake_id"))
	check(not Offenses.evaluate(robot).has(Offenses.OFF_LIMITS), "a fake ID gets you in")


func test_dock_stash() -> void:
	await _start()
	var dock: ChargingDock = level.get_node("Dock")
	check(dock.is_in_reach(robot), "the player starts at their dock")
	check(ChargingDock.find_near(robot) == dock, "and can find it")
	var magnet := _give(&"magnet")
	check(dock.put(inventory, magnet) and _only(dock.stash, magnet) and inventory.count(&"magnet") == 0,
		"items go into the stash")
	for i in Inventory.SLOT_COUNT:
		_give(&"tape")
	check(not dock.take(inventory, magnet) and dock.stash.has(magnet),
		"taking needs a free slot")
	inventory.remove(inventory.slots[0])
	check(dock.take(inventory, magnet) and dock.stash.is_empty(), "and comes back out")
	dock.put(inventory, magnet)
	Suspicion.set_value(40.0)
	check(not dock.is_searchable(), "guards leave the dock alone at low suspicion")
	Suspicion.set_value(90.0)
	check(dock.is_searchable(), "but would search it at high suspicion")
	check(_only(dock.confiscate(), magnet) and dock.stash.is_empty(), "and take everything")
	await _teleport(robot, Vector3(0, 0.05, 8))
	check(ChargingDock.find_near(robot) == null, "the dock only works up close")


func test_holding_reveals_recipes() -> void:
	await _start()
	var revealed: Array[int] = []
	GameState.recipe_revealed.connect(func(recipe: int) -> void: revealed.append(recipe))
	check(GameState.get_known_recipes().is_empty(), "no recipes known at first")
	await _teleport(robot, Vector3(-4, 0.05, 8))
	robot.grab(_item(&"tape", robot.get_hold_position()))
	var tape_recipes := ItemCatalog.recipes_using(&"tape")
	check(GameState.get_known_recipes() == tape_recipes and revealed == tape_recipes,
		"holding tape reveals the recipes that use it (%s)" % [GameState.get_known_recipes()])
	check(not GameState.knows_recipe(1), "but not the ones that don't")
	_give(&"tape")
	check(revealed.size() == tape_recipes.size(), "each recipe is revealed once")


func test_recipe_table_is_valid() -> void:
	for recipe: Dictionary in ItemCatalog.RECIPES:
		var inputs: Array = recipe.inputs
		check(inputs.size() >= 2 and inputs.size() <= ItemCatalog.MAX_INPUTS,
			"%s takes 2 or 3 items" % recipe.result)
		check(ItemCatalog.has(recipe.result), "%s exists" % recipe.result)
		for input: StringName in inputs:
			check(ItemCatalog.has(input), "%s exists" % input)


func test_crafting_chain() -> void:
	await _start()
	var dock: ChargingDock = level.get_node("Dock")
	for id: StringName in [&"tape", &"box_cutter", &"magnet"]:
		dock.stash.append(ItemState.new(id))
	check(dock.craft(0, inventory) == null, "unknown recipes can't be crafted")
	GameState.note_held(&"tape")
	check(not GameState.knows_recipe(1), "the second step isn't known yet")
	var blade := dock.craft(0, inventory)
	check(blade != null and blade.id == &"taped_blade", "tape + box cutter = taped blade")
	check(_only(inventory.get_items(), blade) and dock.stash.size() == 1,
		"ingredients are used up, the result goes into the inventory")
	check(GameState.knows_recipe(1), "making the blade reveals what it goes into")
	var grabber := dock.craft(1, inventory)
	check(grabber != null and grabber.id == &"magnetic_grabber_blade",
		"taped blade + magnet (from the stash) = magnetic grabber blade")
	check(dock.stash.is_empty() and _only(inventory.get_items(), grabber), "both used up")
	check(dock.craft(1, inventory) == null and not dock.can_craft(1, inventory),
		"nothing left to craft with")
	check(grabber.get_max_durability() > blade.get_max_durability(), "each step is sturdier")


func test_key_part_upgrade_installs() -> void:
	await _start()
	var dock: ChargingDock = level.get_node("Dock")
	check(ItemCatalog.is_key_part(&"electromagnet_coil"), "the coil is a key part")
	_give(&"magnet")
	_give(&"electromagnet_coil")
	var recipe := ItemCatalog.recipes_using(&"electromagnet_coil")[0]
	var hands := dock.craft(recipe, inventory)
	check(hands != null and hands.get_kind() == ItemCatalog.Kind.UPGRADE, "crafts magnetic hands")
	_equip(hands)
	inventory.use_equipped()
	check(GameState.has_upgrade(&"magnetic_hands"), "using an upgrade installs it")
	check(inventory.get_items().is_empty(), "for good")


func test_chutes_reject_items() -> void:
	await _start()
	var chute: Chute = level.get_node("Work/Chute")
	var item := _item(&"tape", chute.global_position + Vector3(0, 2, 0))
	check(not chute.takes(item), "chutes don't take items")
	await seconds(1.0)
	check(is_instance_valid(item) and Quota.delivered_count == 0 and Quota.missort_count == 0,
		"an item dropped in is spat back out without counting")


func test_player_keys() -> void:
	await _start(true)
	await _teleport(robot, Vector3(-4, 0.05, 8))
	var item := _item(&"box_cutter", Vector3(-4, 0.3, 7))
	await seconds(0.4)
	await _press("interact")
	check(robot.held == item, "F grabs the item")
	await _press("stow")
	check(robot.held == null and inventory.count(&"box_cutter") == 1, "R stows it")
	await _press("cycle_item")
	check(inventory.get_equipped() != null, "Tab equips it")
	await _press("use_item")
	check(inventory.get_equipped().durability == 5, "V swings it")
	await _press("stow")
	check(robot.held is Item, "R takes the equipped item out")
	robot.drop()
	await _teleport(robot, Vector3(-12, 0.05, 8))
	check(controller.get_prompt().contains("dock"), "the dock is prompted")
	await _press("open_dock")
	check(controller.open_dock == level.get_node("Dock"), "C opens the dock")
	await physics_frames(2)
	var panel := level.get_node("HUD").get_children().filter(
		func(node: Node) -> bool: return node is DockPanel)
	check(panel.size() == 1 and (panel[0] as Control).visible, "and its panel")
	await _press("open_dock")
	check(controller.open_dock == null, "C closes it again")
