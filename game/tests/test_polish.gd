extends TestCase
## Saving and loading, wipes, dock searches, the evidence locker and
## achievement tracking.

const WAREHOUSE := "res://scenes/levels/warehouse.tscn"
const WAREHOUSE_SCRIPT := "res://scripts/levels/warehouse.gd"
const DOCK := "res://scenes/items/charging_dock.tscn"
const ROBOT := "res://scenes/robot/robot.tscn"
const TITLE := "res://scenes/ui/title.tscn"

## In the maintenance bay, by your dock.
const IN_BAY := Vector3(-24, 0.85, 4)
const ON_FLOOR := Vector3(2, 0.85, 4)

var level: Node3D
var robot: RobotBody
var inventory: Inventory


## Starts the warehouse on the floor, with guards, coworkers and cameras
## switched off. With `saved`, it loads from that save instead.
func _start(saved := {}) -> void:
	if not saved.is_empty():
		SaveGame.begin_load(saved)
	level = load(WAREHOUSE).instantiate()
	level.skip_intro = true
	tree.root.add_child(level)
	_nodes.append(level)
	robot = level.get_node("Player")
	inventory = Inventory.of(robot)
	level.get_node("Player/Controller").enabled = false
	level.get_node("Coworkers").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("Security").process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frames(3)
	Dialogue.reset()


func _teleport(pos: Vector3) -> void:
	robot.global_position = pos
	robot.velocity = Vector3.ZERO
	await physics_frames(3)


## The end-of-slice card's achievement lines.
func _summary() -> String:
	return load(WAREHOUSE_SCRIPT).achievement_summary()


func _world_items(id: StringName) -> Array[Item]:
	var found: Array[Item] = []
	for item: Item in tree.get_nodes_in_group(&"items"):
		if item.state.id == id and level.is_ancestor_of(item) \
				and not item.is_queued_for_deletion():
			found.append(item)
	return found


# --- Saving ---

func test_walking_into_the_bay_saves() -> void:
	SaveGame.delete()
	await _start()
	await _teleport(ON_FLOOR)
	SaveGame.delete()
	await physics_frames(3)
	check(not SaveGame.exists(), "nothing is saved out on the floor")
	await _teleport(IN_BAY)
	check(SaveGame.exists(), "walking into the maintenance bay saves")
	var notice: Label = level.get_node("HUD/Notice")
	check(notice.visible and notice.text.contains("saved"), "and says so")
	SaveGame.delete()
	await _teleport(ON_FLOOR)
	Security.start_lockdown()
	await _teleport(IN_BAY)
	check(not SaveGame.exists(), "but not during a lockdown")


func test_save_and_load_round_trip() -> void:
	SaveGame.delete()
	await _start()
	# Progress worth keeping.
	GameState.grant_clearance(1)
	GameState.set_flag(GameState.FLAG_MET_ELLE)
	GameState.set_flag(GameState.FLAG_DIAGNOSTIC_ANOMALIES, 2)
	GameState.install_upgrade(&"wheel_base")
	GameState.wipes = 2
	GameState.lockdowns = 1
	GameState.confiscate([ItemState.new(&"wrench")])
	var cutter := ItemState.new(&"box_cutter")
	cutter.wear(2)
	inventory.add(ItemState.new(&"tape"))
	inventory.add(cutter)
	inventory.select(1)
	var dock: ChargingDock = level.get_node("Dock")
	dock.stash.append(ItemState.new(&"strap"))
	# You took the wheel motor, and left a magnet lying in the bay.
	for motor in _world_items(&"wheel_motor"):
		motor.queue_free()
	Item.spawn(ItemState.new(&"taped_blade"), level.get_node("Items"), Vector3(-18, 0.5, -4))
	await _teleport(ON_FLOOR)
	SaveGame.delete()
	await _teleport(IN_BAY)
	check(SaveGame.exists(), "walking in saved the game")
	var recipes := GameState.get_known_recipes()
	var position := robot.global_position

	# Quit, and start fresh.
	level.queue_free()
	_nodes.clear()
	await physics_frames(2)
	GameState.reset_items()
	GameState.reset_story()
	var saved := SaveGame.read()
	check(not saved.is_empty(), "the save reads back")
	check(saved.get("player", {}).get("zone", "") == "Maintenance Bay",
		"it remembers which zone you were in")
	await _start(saved)

	check(GameState.clearance == 1, "clearance is restored")
	check(GameState.has_flag(GameState.FLAG_MET_ELLE), "story flags are restored")
	check(GameState.get_flag(GameState.FLAG_DIAGNOSTIC_ANOMALIES) is int
		and GameState.get_flag(GameState.FLAG_DIAGNOSTIC_ANOMALIES) == 2,
		"numeric flags come back as ints")
	check(GameState.has_upgrade(&"wheel_base"), "upgrades are restored")
	check(GameState.get_known_recipes() == recipes, "known recipes are restored")
	check(GameState.wipes == 2 and GameState.lockdowns == 1, "wipes and lockdowns are restored")
	check(GameState.evidence.size() == 1 and GameState.evidence[0].id == &"wrench",
		"the evidence locker is restored")
	check(robot.global_position.distance_to(position) < 0.5, "you're where you saved")
	check(inventory.count(&"tape") == 1 and inventory.count(&"box_cutter") == 1,
		"the inventory is restored")
	check(inventory.slots[1] and inventory.slots[1].durability == cutter.durability,
		"with its wear")
	check(inventory.selected == 1, "and the equipped slot")
	dock = level.get_node("Dock")
	check(dock.stash.size() == 1 and dock.stash[0].id == &"strap", "the dock stash is restored")
	await physics_frames(2)
	check(_world_items(&"wheel_motor").is_empty(), "items you took don't come back")
	check(_world_items(&"taped_blade").size() == 1, "items you left lying around are still there")
	check(level.on_the_floor, "a loaded game skips the diagnostics")
	var carrier: KeycardCarrier = level.get_node("Guards/Supervisor/Keycard")
	check(not carrier.has_card, "the supervisor no longer wears a card you already have")
	SaveGame.delete()


func test_title_menu_offers_continue_only_with_a_save() -> void:
	SaveGame.delete()
	var title: TitleMenu = spawn(TITLE)
	await physics_frames(1)
	check(title.continue_button.disabled, "no save, no Continue")
	title.queue_free()
	_nodes.clear()
	SaveGame.write({"version": SaveGame.VERSION, "scene": WAREHOUSE,
		"game_state": {"clearance": 1}, "player": {"zone": "Maintenance Bay"}})
	title = spawn(TITLE)
	await physics_frames(1)
	check(not title.continue_button.disabled, "a save offers Continue")
	SaveGame.delete()


# --- Wipes ---

func test_wipe_confiscates_what_you_carry_and_keeps_the_rest() -> void:
	SaveGame.delete()
	await _start()
	GameState.grant_clearance(1)
	GameState.install_upgrade(&"wheel_base")
	inventory.add(ItemState.new(&"box_cutter"))
	inventory.add(ItemState.new(&"tape"))
	var dock: ChargingDock = level.get_node("Dock")
	dock.stash.append(ItemState.new(&"strap"))
	await _teleport(Vector3(4, 0.85, -18))
	var wrench := Item.spawn(ItemState.new(&"wrench"), level, robot.get_hold_position())
	robot.grab(wrench)
	await physics_frames(2)
	Security.start_lockdown()
	Security.catch_player()
	await seconds(3.0)

	check(inventory.get_items().is_empty(), "your inventory is confiscated")
	check(robot.held == null, "and whatever was in your hands")
	check(not is_instance_valid(wrench), "the held item doesn't stay behind")
	var ids := GameState.evidence.map(func(state: ItemState) -> StringName: return state.id)
	check(ids.size() == 3 and ids.has(&"box_cutter") and ids.has(&"tape") and ids.has(&"wrench"),
		"all of it goes to the evidence locker (got %s)" % [ids])
	check(dock.stash.size() == 1, "your dock stash is safe")
	check(GameState.clearance == 1, "clearance is kept")
	check(GameState.has_upgrade(&"wheel_base"), "upgrades are kept")
	check(GameState.wipes == 1, "the wipe is counted")
	var respawn: Marker3D = level.get_node("Respawn")
	check(robot.global_position.distance_to(respawn.global_position) < 1.0,
		"you wake up on the repair table")
	check(Dialogue.is_playing(&"wipe_first"), "Elle restores you")
	check(SaveGame.exists(), "the wipe is saved, so quitting doesn't undo it")

	Dialogue.reset()
	await _teleport(Vector3(4, 0.85, -18))
	Security.start_lockdown()
	Security.catch_player()
	await seconds(3.0)
	check(GameState.wipes == 2, "a second wipe")
	check(Dialogue.is_playing(&"wipe_second"), "and Elle's lines change with it")
	check(DialogueLines.wipe_conversation(5) == &"wipe_many", "and keep changing")
	SaveGame.delete()


# --- Dock searches ---

func test_dock_is_searched_only_when_suspicion_is_high() -> void:
	var dock: ChargingDock = spawn(DOCK)
	dock.stash.append(ItemState.new(&"tape"))
	dock.stash.append(ItemState.new(&"box_cutter"))
	var delay := Security.dock_search_delay
	Security.dock_search_delay = 0.5
	Suspicion.enabled = true
	Suspicion.set_value(dock.search_suspicion - 10.0)
	await seconds(1.0)
	check(not Security.is_dock_search_scheduled(), "moderate suspicion doesn't get a search")
	check(dock.stash.size() == 2, "and the stash is safe")

	# High suspicion that turns into a lockdown: security is busy with you.
	Suspicion.set_value(dock.search_suspicion + 5.0)
	await physics_frames(2)
	check(Security.is_dock_search_scheduled(), "high suspicion schedules a search")
	Security.start_lockdown()
	await seconds(1.0)
	check(dock.stash.size() == 2, "a lockdown calls the search off")
	Security.reset()

	var searched := []
	Security.dock_searched.connect(func(_dock: ChargingDock, items: Array[ItemState]) -> void:
		searched.append(items.size()))
	Suspicion.set_value(dock.search_suspicion + 5.0)
	await physics_frames(2)
	Suspicion.set_value(dock.search_suspicion - 20.0)
	await seconds(1.0)
	check(dock.stash.is_empty(), "once scheduled, the search happens even if you calm down")
	check(GameState.evidence.size() == 2, "searched items go to the evidence locker")
	check(searched == [2], "and the level hears about it")
	Suspicion.set_value(dock.search_suspicion + 5.0)
	dock.stash.append(ItemState.new(&"tape"))
	await seconds(1.0)
	check(dock.stash.size() == 1, "there's a cooldown before the next search")
	Security.dock_search_delay = delay
	Suspicion.enabled = false


# --- The evidence locker ---

func test_evidence_locker_gives_your_things_back() -> void:
	await _start()
	GameState.grant_clearance(1)
	for id: StringName in [&"tape", &"strap", &"wrench", &"magnet", &"box_cutter"]:
		GameState.confiscate([ItemState.new(id)])
	var locker: EvidenceLocker = level.get_node("EvidenceLocker")
	var holding: Zone = level.get_node("Zones/Holding")
	check(holding.required_clearance > GameState.clearance,
		"the holding cage is off limits at your clearance")
	await _teleport(Vector3(31.2, 0.85, -1.5))
	check(holding.overlaps_body(robot), "the locker is inside the holding cage")
	var controller: PlayerController = level.get_node("Player/Controller")
	check(controller.get_prompt().contains("confiscated items (5)"), "the prompt offers them back")
	var taken := locker.retrieve(inventory)
	check(taken.size() == Inventory.SLOT_COUNT, "you take back as many as fit")
	check(locker.get_count() == 1 and GameState.evidence.size() == 1, "the rest wait")
	var sign: Label3D = locker.get_node("Sign")
	check(sign.text.contains("1 item"), "the locker shows what's left")
	inventory.remove(inventory.slots[0])
	check(locker.retrieve(inventory).size() == 1, "make room and take the last one")
	check(GameState.evidence.is_empty(), "the locker is empty")


# --- Achievements ---

func test_achievement_tracking() -> void:
	check(GameState.is_low_profile() and GameState.is_ghost(), "a fresh game is on track for both")
	check(_summary().contains("LOW PROFILE: on track"), "the card says so")
	var player: RobotBody = spawn(ROBOT)
	player.add_to_group(&"player")
	var guard: RobotBody = spawn(ROBOT)
	player.global_position = Vector3(0, 0.1, 0)
	guard.global_position = Vector3(0, 0.1, -1.5)
	await physics_frames(2)
	Combat.hit(guard, player, Vector3.FORWARD, 4.0, 0.5)
	check(GameState.fights == 0, "getting hit isn't starting a fight")
	Combat.hit(player, guard, Vector3.FORWARD, 4.0, 0.5)
	check(GameState.fights == 1, "hitting someone is")
	check(GameState.is_low_profile() and not GameState.is_ghost(), "that loses Ghost only")
	check(_summary().contains("GHOST: missed (1 fight)"), "the card says why")
	Suspicion.enabled = true
	Suspicion.add(Suspicion.MAX)
	check(Security.lockdown and GameState.lockdowns == 1, "a lockdown is counted")
	check(not GameState.is_low_profile(), "and loses Low Profile")
	check(_summary().contains("LOW PROFILE: missed (1 lockdown)"), "the card says so")
	Suspicion.enabled = false
	var saved := GameState.to_dict()
	GameState.reset_story()
	GameState.from_dict(saved)
	check(GameState.lockdowns == 1 and GameState.fights == 1, "tracking survives a save")


# --- Fixes from jam feedback ---

func test_buttons_prompt_you_to_grow() -> void:
	var room: Node3D = spawn("res://scenes/world/test_room.tscn")
	await physics_frames(2)
	var button: PushButton = room.get_node("Geometry/HighButton")
	var player: RobotBody = tree.get_first_node_in_group(&"player")
	var below := button.global_position
	below.y = player.global_position.y
	player.global_position = below + Vector3(0.0, 0.0, 0.01)
	check(button.get_hint(player).contains("grow"), "a button over your head says to grow")
	player.global_position = below + Vector3(10.0, 0.0, 0.0)
	check(button.get_hint(player) == "", "but not from across the room")
