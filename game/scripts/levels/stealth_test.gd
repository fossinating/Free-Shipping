extends Node3D
## Sandbox for suspicion: cameras, coworkers, zones, and a work station.

const DELIVERY_INTERVAL := 60.0

@export var hud: Hud


func _ready() -> void:
	Quota.reset(0)
	Quota.expected_interval = DELIVERY_INTERVAL
	Suspicion.reset()
	Suspicion.enabled = true
	Suspicion.maxed.connect(_on_maxed)


func _exit_tree() -> void:
	Suspicion.enabled = false
	Quota.expected_interval = 0.0


func _on_maxed() -> void:
	hud.show_card("SUSPICION MAXED\nSecurity has been alerted", 3.0)
