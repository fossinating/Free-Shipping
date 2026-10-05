extends Node3D
## The warehouse, as far as the vertical slice goes: the maintenance bay
## (your hub), Fulfillment with its Electronics and Hardware departments,
## and Receiving behind a level 1 scanner.
##
## After the accident you wake on the repair table and fake your way
## through the diagnostics. The maintenance robot sends you back to work,
## and the static only you can hear leads off your route to Elle's radio in
## Electronics. Elle points you at a level 1 keycard in Hardware; that
## opens Receiving, which holds the wheel motor and the level 2 keycard.
## Getting that card ends the slice.
##
## Walking into the maintenance bay saves the game. Getting caught in a
## lockdown wipes you: you wake in the bay without what you carried, which
## goes to the holding locker in Receiving.

## Outside of shifts, a delivery is expected about this often.
const DELIVERY_INTERVAL := 90.0
## Signal strengths at which garbled bits of Elle come through the static.
const FAINT_SIGNAL := 0.2
const CLOSE_SIGNAL := 0.55
## Faint static while the diagnostics run, before and after you notice it.
const DIAGNOSTICS_STATIC := 0.06
const NOTICED_STATIC := 0.16
## How close you have to be for M-7 to shoo you out of the bay.
const SHOO_DISTANCE := 2.5
const SHOO_COOLDOWN := 30.0
## After meeting Elle, she brings up keycards after this long even if you
## never make that delivery.
const HINT_DELAY := 60.0

@export var hud: Hud
@export var player: RobotBody
@export var maintenance_bot: RobotBody
@export var diagnostics: Diagnostics
@export var receiver: SignalReceiver
@export var radio: Radio
@export var bay_door: Door
## Walking into Hardware after meeting Elle gets you her keycard hint.
@export var hardware_zone: Zone
## Where a wiped robot wakes up.
@export var respawn: Marker3D
## Your charging dock (saved with the game, and searched when suspicion
## gets high).
@export var dock: ChargingDock
## Walking in here saves the game.
@export var bay_zone: Zone
## Start with the diagnostics already done (tests and playtests).
@export var skip_intro := false

var controller: PlayerController
## Back on the floor: the signal meter is on and quota counts.
var on_the_floor := false

var _heard := {}
var _awaiting_delivery := false
var _shoo_time := 0.0
var _hint_time := HINT_DELAY
var _in_bay := false
## Loaded from a save rather than started fresh.
var _loaded := false


func _ready() -> void:
	controller = player.get_node("Controller")
	Quota.reset(0)
	Quota.expected_interval = 0.0
	Suspicion.reset()
	Security.reset()
	Suspicion.enabled = true
	Security.lockdown_started.connect(_on_lockdown_started)
	Security.lockdown_ended.connect(_on_lockdown_ended)
	Security.caught.connect(_on_caught)
	Security.dock_search_scheduled.connect(_on_dock_search_scheduled)
	Security.dock_searched.connect(_on_dock_searched)
	GameState.evidence_changed.connect(_on_evidence_changed)
	Quota.delivered.connect(_on_delivered)
	GameState.clearance_changed.connect(_on_clearance_changed)
	radio.tuned_in.connect(_on_radio_tuned_in)
	diagnostics.test_started.connect(_on_test_started)
	diagnostics.finished.connect(_on_diagnostics_finished)
	for checkpoint: ScannerCheckpoint in get_tree().get_nodes_in_group(&"checkpoints"):
		if is_ancestor_of(checkpoint):
			checkpoint.scanned.connect(_on_scanned.bind(checkpoint))
	var saved := SaveGame.take_pending()
	if not saved.is_empty():
		_loaded = true
		SaveGame.apply_level(saved, self, player, dock)
		# You're standing where you saved, so this isn't a new arrival.
		_in_bay = true
		hud.show_card("BACKUP RESTORED", 2.0)
	if skip_intro:
		GameState.set_flag(GameState.FLAG_DIAGNOSTICS_DONE)
	if GameState.has_flag(GameState.FLAG_DIAGNOSTICS_DONE):
		_back_to_work(false)
	else:
		_wake()


func _exit_tree() -> void:
	Suspicion.enabled = false
	Suspicion.ceiling = Suspicion.MAX
	Quota.expected_interval = 0.0
	Dialogue.reset()


func _physics_process(delta: float) -> void:
	_watch_player()
	_shoo_time = maxf(0.0, _shoo_time - delta)
	if not on_the_floor:
		return
	_check_bay()
	if _shoo_time <= 0.0 and player.global_position.distance_to(
			maintenance_bot.global_position) < SHOO_DISTANCE:
		_shoo_time = SHOO_COOLDOWN
		Dialogue.play(&"bay_return")
	if GameState.has_flag(GameState.FLAG_MET_ELLE):
		if not GameState.has_flag(GameState.FLAG_KEYCARD_HINT):
			_hint_time -= delta
			if _hint_time <= 0.0 or (hardware_zone and hardware_zone.overlaps_body(player)):
				_give_keycard_hint()
		return
	# Bits of Elle come through as you get closer.
	var strength := receiver.get_raw_strength()
	if strength >= FAINT_SIGNAL:
		_hear_once(&"static_faint")
	if strength >= CLOSE_SIGNAL:
		_hear_once(&"static_close")


func _wake() -> void:
	controller.enabled = false
	receiver.ambient = DIAGNOSTICS_STATIC
	await hud.fade(1.0, 0.0)
	await hud.show_card("REBOOTING...\nCONTROL CHIP: NOT RESPONDING", 2.5)
	controller.enabled = true
	hud.fade(0.0, 2.0)
	hud.show_notice("Nobody is steering you. Act like somebody is.")
	await Dialogue.play(&"bay_wake").wait()
	diagnostics.start()


func _on_test_started(index: int) -> void:
	# Partway in, you notice the static. The maintenance robot doesn't.
	if index == 1:
		receiver.ambient = NOTICED_STATIC
		hud.show_notice("A faint static hisses inside your head. M-7 doesn't seem to hear it.")


func _on_diagnostics_finished(anomalies: int) -> void:
	GameState.set_flag(GameState.FLAG_DIAGNOSTICS_DONE)
	GameState.set_flag(GameState.FLAG_DIAGNOSTIC_ANOMALIES, anomalies)
	var outcome := &"diagnostics_clean" if anomalies == 0 else &"diagnostics_flagged"
	await Dialogue.play(outcome).wait()
	_back_to_work(true)


## The maintenance robot sends you back out. The static follows you.
func _back_to_work(announce: bool) -> void:
	on_the_floor = true
	_shoo_time = SHOO_COOLDOWN
	bay_door.open()
	receiver.ambient = 0.0
	receiver.tracking = not GameState.has_flag(GameState.FLAG_MET_ELLE)
	radio.listening = true
	Quota.expected_interval = DELIVERY_INTERVAL
	_update_objective()
	if announce and not GameState.has_flag(GameState.FLAG_MET_ELLE):
		hud.show_notice("Your chip is picking up a signal. Stronger means closer.")
		Dialogue.play(&"floor_announcement")


## The objective for wherever the story is, with a reminder how to save.
func _update_objective() -> void:
	var text := _objective_text()
	if not GameState.evidence.is_empty():
		text += "\nSecurity has your things in the holding locker in Receiving."
	hud.show_objective(text + "\n\nTo save, walk back into the maintenance bay.")


func _objective_text() -> String:
	if not GameState.has_flag(GameState.FLAG_MET_ELLE):
		return ("Report to Station C and deliver to Chute C.\n"
			+ "Something keeps hissing in the static...")
	elif GameState.clearance >= 2:
		return ("You've reached the end of the vertical slice.\n"
			+ "Keep exploring as long as you like.")
	elif GameState.clearance == 1:
		return ("Receiving is open. Find a level 2 keycard.\n"
			+ "Keep an eye out for a wheel motor.")
	elif _awaiting_delivery:
		return "Get back on your route before anyone notices: deliver a package."
	elif GameState.has_flag(GameState.FLAG_KEYCARD_HINT):
		return ("Get a level 1 keycard in Hardware: off the supervisor,\n"
			+ "or from his office through the vent.")
	else:
		return "Keep up appearances: deliver packages from Station C to Chute C."


func _hear_once(id: StringName) -> void:
	if _heard.has(id):
		return
	_heard[id] = true
	Dialogue.play(id)


func _on_radio_tuned_in() -> void:
	GameState.set_flag(GameState.FLAG_MET_ELLE)
	receiver.tracking = false
	hud.hide_objective()
	hud.show_notice("Signal locked.")
	_hint_time = HINT_DELAY
	var contact := Dialogue.play(&"elle_first_contact", true)
	Dialogue.play(&"bay_backup_hint")
	await contact.wait()
	_awaiting_delivery = true
	_update_objective()


func _on_delivered(_package: Package) -> void:
	if not _awaiting_delivery:
		return
	_awaiting_delivery = false
	Dialogue.play(&"elle_back_to_work")
	_give_keycard_hint()


func _give_keycard_hint() -> void:
	if GameState.has_flag(GameState.FLAG_KEYCARD_HINT):
		return
	GameState.set_flag(GameState.FLAG_KEYCARD_HINT)
	_awaiting_delivery = false
	if GameState.clearance == 0:
		Dialogue.play(&"elle_keycard_hint")
	_update_objective()


func _on_clearance_changed(level: int) -> void:
	if level <= 0:
		return
	if level >= 2:
		_end_slice()
		return
	hud.show_card("CLEARANCE %d\nYour badge now opens Receiving" % level, 3.0)
	Dialogue.play(&"elle_receiving")
	_update_objective()


## The level 2 keycard: the end of the vertical slice. You can keep playing.
func _end_slice() -> void:
	if GameState.has_flag(GameState.FLAG_SLICE_COMPLETE):
		return
	GameState.set_flag(GameState.FLAG_SLICE_COMPLETE)
	_update_objective()
	Dialogue.play(&"elle_slice_end" if GameState.wipes == 0 else &"elle_slice_end_wiped", true)
	hud.show_card("LEVEL 2 KEYCARD\n\nEND OF THE VERTICAL SLICE\n"
		+ "Thanks for playing. Returns comes next.\n\n" + achievement_summary(), 10.0)


## How the achievements stand, for the end-of-slice card.
static func achievement_summary() -> String:
	var lines: PackedStringArray = []
	if GameState.is_low_profile():
		lines.append("LOW PROFILE: on track (no lockdowns)")
	else:
		lines.append("LOW PROFILE: missed (%d lockdown%s)" % [GameState.lockdowns,
			"" if GameState.lockdowns == 1 else "s"])
	if GameState.is_ghost():
		lines.append("GHOST: on track (no lockdowns, no fights)")
	elif GameState.fights > 0:
		lines.append("GHOST: missed (%d fight%s)" % [GameState.fights,
			"" if GameState.fights == 1 else "s"])
	else:
		lines.append("GHOST: missed (a lockdown)")
	lines.append("Wipes: %d" % GameState.wipes)
	return "\n".join(lines)


func _on_scanned(granted: bool, contraband: bool, checkpoint: ScannerCheckpoint) -> void:
	if not granted:
		hud.flash_denied("%s requires clearance %d" % [checkpoint.place_name,
			checkpoint.required_clearance], "ACCESS DENIED")
	if contraband:
		hud.show_notice("The scanner logged contraband. Stash it at your dock next time.")
	elif granted:
		hud.show_notice("Badge accepted: %s" % checkpoint.place_name)


## The maintenance robot keeps its eyes on you.
func _watch_player() -> void:
	var to := player.global_position - maintenance_bot.global_position
	if Vector2(to.x, to.z).length() > 0.1:
		maintenance_bot.facing_yaw = atan2(-to.x, -to.z)


func _on_lockdown_started() -> void:
	hud.show_card("LOCKDOWN\nSecurity is hunting you", 2.5)


func _on_lockdown_ended() -> void:
	hud.show_card("Lockdown lifted\nThe zone is on alert", 2.5)


## Walking into the bay saves the game (not during a lockdown).
func _check_bay() -> void:
	var inside := bay_zone != null and bay_zone.overlaps_body(player)
	if inside and not _in_bay and not Security.lockdown:
		if save_game():
			hud.show_notice("Backed up at the maintenance bay. Progress saved.")
	_in_bay = inside


func save_game() -> bool:
	return SaveGame.save(self, player, dock)


## Caught: dragged back and re-imaged. You keep clearance and upgrades,
## lose what you carry, and Elle restores you from her backup.
func _on_caught() -> void:
	controller.enabled = false
	controller.open_dock = null
	await hud.fade(1.0, 0.3)
	var taken := wipe()
	hud.show_card("CAUGHT\nRE-IMAGING UNIT FS-4471...", 2.5)
	await get_tree().create_timer(2.0).timeout
	controller.enabled = true
	hud.fade(0.0, 1.0)
	if not taken.is_empty():
		hud.show_notice("Confiscated: %d item%s. They went to the holding locker in Receiving."
			% [taken.size(), "" if taken.size() == 1 else "s"])
	Dialogue.play(DialogueLines.wipe_conversation(GameState.wipes), true)


## The wipe itself: confiscates everything you carry, counts the wipe,
## puts you on the repair table and saves. Returns what was taken.
func wipe() -> Array[ItemState]:
	var taken: Array[ItemState] = []
	var inventory := Inventory.of(player)
	if inventory:
		taken = inventory.confiscate_all()
	elif player.held:
		player.drop()
	GameState.confiscate(taken)
	GameState.wipes += 1
	player.release()
	player.global_position = respawn.global_position
	player.rotation.y = respawn.rotation.y
	player.facing_yaw = respawn.rotation.y
	player.velocity = Vector3.ZERO
	Suspicion.set_value(Security.aftermath_suspicion)
	_in_bay = true
	if on_the_floor:
		save_game()
	return taken


func _on_dock_search_scheduled() -> void:
	hud.show_notice("Security flagged your dock for a search. Empty it, fast.")


func _on_dock_searched(_searched: ChargingDock, items: Array[ItemState]) -> void:
	hud.show_card("DOCK SEARCHED\n%d item%s confiscated" % [items.size(),
		"" if items.size() == 1 else "s"], 2.5)


func _on_evidence_changed() -> void:
	if on_the_floor:
		_update_objective()
