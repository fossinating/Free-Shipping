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
## Where a caught robot ends up. Milestone 9 makes this a proper wipe.
@export var respawn: Marker3D
## Start with the diagnostics already done (tests and playtests).
@export var skip_intro := false

var controller: PlayerController
## Back on the floor: the signal meter is on and quota counts.
var on_the_floor := false

var _heard := {}
var _awaiting_delivery := false
var _shoo_time := 0.0
var _hint_time := HINT_DELAY


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
	Quota.delivered.connect(_on_delivered)
	GameState.clearance_changed.connect(_on_clearance_changed)
	radio.tuned_in.connect(_on_radio_tuned_in)
	diagnostics.test_started.connect(_on_test_started)
	diagnostics.finished.connect(_on_diagnostics_finished)
	for checkpoint: ScannerCheckpoint in get_tree().get_nodes_in_group(&"checkpoints"):
		if is_ancestor_of(checkpoint):
			checkpoint.scanned.connect(_on_scanned.bind(checkpoint))
	if skip_intro or GameState.has_flag(GameState.FLAG_DIAGNOSTICS_DONE):
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


## The objective for wherever the story is.
func _update_objective() -> void:
	if not GameState.has_flag(GameState.FLAG_MET_ELLE):
		hud.show_objective("Report to Station C and deliver to Chute C.\n"
			+ "Something keeps hissing in the static...")
	elif GameState.clearance >= 2:
		hud.show_objective("You've reached the end of the vertical slice.\n"
			+ "Keep exploring as long as you like.")
	elif GameState.clearance == 1:
		hud.show_objective("Receiving is open. Find a level 2 keycard.\n"
			+ "Keep an eye out for a wheel motor.")
	elif _awaiting_delivery:
		hud.show_objective("Get back on your route before anyone notices: deliver a package.")
	elif GameState.has_flag(GameState.FLAG_KEYCARD_HINT):
		hud.show_objective("Get a level 1 keycard in Hardware: off the supervisor,\n"
			+ "or from his office through the vent.")
	else:
		hud.show_objective("Keep up appearances: deliver packages from Station C to Chute C.")


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
	await Dialogue.play(&"elle_first_contact", true).wait()
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
	Dialogue.play(&"elle_slice_end", true)
	hud.show_card("LEVEL 2 KEYCARD\n\nEND OF THE VERTICAL SLICE\n"
		+ "Thanks for playing. Returns comes next.", 8.0)


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


func _on_caught() -> void:
	controller.enabled = false
	await hud.fade(1.0, 0.3)
	hud.show_card("CAUGHT\nDragged back to maintenance", 2.5)
	player.global_position = respawn.global_position
	player.velocity = Vector3.ZERO
	Suspicion.set_value(Security.aftermath_suspicion)
	await get_tree().create_timer(2.0).timeout
	controller.enabled = true
	await hud.fade(0.0, 1.0)
