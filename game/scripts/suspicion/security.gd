extends Node
## Security's response: lockdowns, sightings, noise, and dispatching guards
## to check on robots that fall behind.
##
## A lockdown starts when suspicion maxes out. It ends once no watcher has
## seen you for a while; hiding or blending back in (carrying normal stock)
## makes that go faster. Afterwards suspicion stays high and the zone where
## it happened stays on heightened alert for a while.

signal lockdown_started
signal lockdown_ended
## The player was seen during a lockdown.
signal sighted(position: Vector3)
## A guard caught the player during a lockdown.
signal caught
## Something loud happened. Guards in range come to look.
signal noise(position: Vector3, radius: float)
## A guard should go check on the player (they're behind on deliveries).
signal check_in_requested

## Seconds unseen before a lockdown ends.
@export var lockdown_end_time := 12.0
## How much faster the lockdown winds down while hidden or blending in.
@export var blend_speedup := 2.0
## Suspicion right after a lockdown: lower, but still on thin ice.
@export var aftermath_suspicion := 60.0
@export var heightened_time := 120.0
@export var heightened_multiplier := 1.5
## While under review, a guard checks in this often.
@export var check_in_interval := 45.0

var lockdown := false
var last_known_position := Vector3.ZERO
## Zone where the last lockdown happened, on alert until heightened_until.
var heightened_zone: Zone
var heightened_until := 0.0

var _unseen := 0.0
var _check_in_timer := 0.0


func _ready() -> void:
	Suspicion.maxed.connect(start_lockdown)


func _physics_process(delta: float) -> void:
	if lockdown:
		var player := _player()
		var rate := blend_speedup if player and is_blending_in(player) else 1.0
		_unseen += delta * rate
		if _unseen >= lockdown_end_time:
			end_lockdown()
	elif Suspicion.enabled and Suspicion.is_under_review():
		_check_in_timer -= delta
		if _check_in_timer <= 0.0:
			_check_in_timer = check_in_interval
			check_in_requested.emit()
	else:
		_check_in_timer = 0.0


func reset() -> void:
	lockdown = false
	heightened_zone = null
	heightened_until = 0.0
	_unseen = 0.0
	_check_in_timer = 0.0


func start_lockdown() -> void:
	if lockdown:
		return
	lockdown = true
	_unseen = 0.0
	var player := _player()
	if player:
		last_known_position = player.global_position
		heightened_zone = _most_specific_zone(player)
	lockdown_started.emit()


func end_lockdown() -> void:
	if not lockdown:
		return
	lockdown = false
	heightened_until = _now() + heightened_time
	Suspicion.set_value(aftermath_suspicion)
	lockdown_ended.emit()


## Watchers call this when they see the player during a lockdown.
func report_sighting(position: Vector3) -> void:
	if not lockdown:
		return
	_unseen = 0.0
	last_known_position = position
	sighted.emit(position)


func catch_player() -> void:
	if not lockdown:
		return
	lockdown = false
	caught.emit()


func make_noise(position: Vector3, radius: float) -> void:
	noise.emit(position, radius)


## 0 when just seen, 1 when the lockdown is about to end.
func get_lockdown_progress() -> float:
	return clampf(_unseen / lockdown_end_time, 0.0, 1.0)


## Extra watcher sensitivity at this position (the aftermath alert).
func get_alert_multiplier(position: Vector3) -> float:
	if heightened_zone and is_instance_valid(heightened_zone) and _now() < heightened_until \
			and heightened_zone.contains_point(position):
		return heightened_multiplier
	return 1.0


## Hidden, or doing something a loyal worker would do.
func is_blending_in(robot: RobotBody) -> bool:
	return HidingSpot.is_hidden(robot) or (robot.held != null and robot.held.is_stock()
		and not Inventory.shows_contraband(robot))


func _player() -> RobotBody:
	return get_tree().get_first_node_in_group(&"player") as RobotBody


func _most_specific_zone(robot: RobotBody) -> Zone:
	var best: Zone = null
	for zone in Zone.zones_at(robot):
		if best == null or zone.get_volume() < best.get_volume():
			best = zone
	return best


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
