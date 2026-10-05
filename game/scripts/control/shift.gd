class_name Shift
extends Node
## A work shift: a title, a quota, and ShiftStep children run in order.

@export var title := "Shift"
## Deliveries the HUD shows as this shift's quota.
@export var quota := 0


func get_steps() -> Array[ShiftStep]:
	var steps: Array[ShiftStep] = []
	for child in get_children():
		if child is ShiftStep:
			steps.append(child)
	return steps
