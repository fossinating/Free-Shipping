extends Node
## Tracks deliveries against the current work quota. Chutes report here;
## the HUD and, later, suspicion read from it.

signal changed
signal delivered(package: Package)
signal missorted(package: Package)

## Deliveries needed this shift. 0 means no quota is set.
var target := 0
var delivered_count := 0
var missort_count := 0
## Outside of shifts there's no schedule, but robots are still expected to
## deliver one package this often (seconds). 0 turns the expectation off.
var expected_interval := 0.0

var _owed := 0.0


func _physics_process(delta: float) -> void:
	if expected_interval > 0.0:
		_owed += delta / expected_interval


## Whole deliveries you're behind on.
func get_backlog() -> int:
	return floori(_owed)


func reset(new_target: int) -> void:
	target = new_target
	delivered_count = 0
	missort_count = 0
	_owed = 0.0
	changed.emit()


func is_met() -> bool:
	return target > 0 and delivered_count >= target


func record_delivery(package: Package) -> void:
	delivered_count += 1
	_owed = maxf(0.0, _owed - 1.0)
	delivered.emit(package)
	changed.emit()


func record_missort(package: Package) -> void:
	missort_count += 1
	missorted.emit(package)
	changed.emit()
