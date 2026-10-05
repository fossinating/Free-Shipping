extends Node3D
## The maintenance bay, your hub, and the slice of Fulfillment it opens
## onto. After the accident you wake on the repair table and have to fake
## your way through the diagnostics. Then the maintenance robot sends you
## back to work, and the static only you can hear leads off your route to
## Elle's radio in Electronics.

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

@export var hud: Hud
@export var player: RobotBody
@export var maintenance_bot: RobotBody
@export var diagnostics: Diagnostics
@export var receiver: SignalReceiver
@export var radio: Radio
@export var bay_door: Door
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
	radio.tuned_in.connect(_on_radio_tuned_in)
	diagnostics.test_started.connect(_on_test_started)
	diagnostics.finished.connect(_on_diagnostics_finished)
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
	receiver.tracking = true
	radio.listening = true
	Quota.expected_interval = DELIVERY_INTERVAL
	if GameState.has_flag(GameState.FLAG_MET_ELLE):
		hud.show_objective("Keep up appearances: deliver packages from Station C to Chute C.")
		return
	hud.show_objective("Report to Station C and deliver to Chute C.\n"
		+ "Something keeps hissing in the static...")
	if announce:
		hud.show_notice("Your chip is picking up a signal. Stronger means closer.")
		Dialogue.play(&"floor_announcement")


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
	await Dialogue.play(&"elle_first_contact", true).wait()
	_awaiting_delivery = true
	hud.show_objective("Get back on your route before anyone notices: deliver a package.")


func _on_delivered(_package: Package) -> void:
	if not _awaiting_delivery:
		return
	_awaiting_delivery = false
	hud.show_objective("Keep up appearances: deliver packages from Station C to Chute C.")
	Dialogue.play(&"elle_back_to_work")


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
