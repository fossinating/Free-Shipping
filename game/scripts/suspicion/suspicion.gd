extends Node
## The suspicion meter: how close security is to realizing you're free.
## Watchers add to it; doing your job and staying out of sight lower it.

signal changed(value: float)
## Hit the top. Milestone 5 turns this into a lockdown.
signal maxed

const MAX := 100.0

@export var decay_rate := 3.0
## Seconds without new suspicion before it starts to decay.
@export var decay_delay := 4.0
## How much each delivery lowers suspicion.
@export var delivery_relief := 6.0
## Deliveries behind schedule before you're put under review.
@export var review_backlog := 2
## While under review, every watcher is this much more sensitive.
@export var review_multiplier := 1.5

## Off while the robot is still under control.
var enabled := false
var value := 0.0
## Suspicion never decays below this (lockdown aftermath raises it).
var floor_value := 0.0
## Most recent reason suspicion went up, for the HUD.
var last_reason := ""

var _quiet_time := 0.0
var _seen_by := {}
var _alarmed_by := {}
var _maxed := false


func _ready() -> void:
	Quota.delivered.connect(func(_package: Package) -> void: relieve(delivery_relief))


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_quiet_time += delta
	if _quiet_time > decay_delay and value > floor_value:
		_set_value(maxf(floor_value, value - decay_rate * delta))


func reset() -> void:
	value = 0.0
	floor_value = 0.0
	last_reason = ""
	_quiet_time = 0.0
	_seen_by.clear()
	_alarmed_by.clear()
	_maxed = false
	changed.emit(value)


## Raises suspicion. Amounts are scaled up while under review.
func add(amount: float, reason := "") -> void:
	if not enabled or amount <= 0.0:
		return
	_quiet_time = 0.0
	last_reason = reason
	_set_value(minf(MAX, value + amount * get_multiplier()))
	if value >= MAX and not _maxed:
		_maxed = true
		maxed.emit()


## Sets the meter directly, re-arming `maxed` if it drops below the top.
func set_value(new_value: float) -> void:
	_set_value(clampf(new_value, 0.0, MAX))
	if value < MAX:
		_maxed = false


func relieve(amount: float) -> void:
	if enabled:
		_set_value(maxf(floor_value, value - amount))


func get_multiplier() -> float:
	return review_multiplier if is_under_review() else 1.0


## Falling behind on deliveries makes every watcher more sensitive.
func is_under_review() -> bool:
	return Quota.get_backlog() >= review_backlog


## Watchers report every frame whether they can see the player.
func report(watcher: Node, sees: bool, alarmed: bool) -> void:
	_seen_by[watcher] = sees
	_alarmed_by[watcher] = alarmed


func is_watched() -> bool:
	return _any(_seen_by)


## Something can see you doing something suspicious right now.
func is_alarmed() -> bool:
	return _any(_alarmed_by)


func _any(reports: Dictionary) -> bool:
	for watcher in reports.keys():
		if not is_instance_valid(watcher):
			reports.erase(watcher)
		elif reports[watcher]:
			return true
	return false


func _set_value(new_value: float) -> void:
	if is_equal_approx(new_value, value):
		return
	value = new_value
	changed.emit(value)
