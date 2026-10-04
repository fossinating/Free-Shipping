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


func reset(new_target: int) -> void:
	target = new_target
	delivered_count = 0
	missort_count = 0
	changed.emit()


func is_met() -> bool:
	return target > 0 and delivered_count >= target


func record_delivery(package: Package) -> void:
	delivered_count += 1
	delivered.emit(package)
	changed.emit()


func record_missort(package: Package) -> void:
	missort_count += 1
	missorted.emit(package)
	changed.emit()
