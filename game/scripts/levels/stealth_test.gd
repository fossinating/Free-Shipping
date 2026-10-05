extends Node3D
## Sandbox level script (stealth_test and item_test): turns suspicion on,
## expects a delivery every minute, and handles lockdowns and being caught.

const DELIVERY_INTERVAL := 60.0

@export var hud: Hud
@export var player: RobotBody
## Where a caught robot ends up. Milestone 9 makes this a proper wipe.
@export var respawn: Marker3D


func _ready() -> void:
	Quota.reset(0)
	Quota.expected_interval = DELIVERY_INTERVAL
	Suspicion.reset()
	Security.reset()
	Suspicion.enabled = true
	Security.lockdown_started.connect(func() -> void:
		hud.show_card("LOCKDOWN\nSecurity is hunting you", 2.5))
	Security.lockdown_ended.connect(func() -> void:
		hud.show_card("Lockdown lifted\nThe zone is on alert", 2.5))
	Security.caught.connect(_on_caught)


func _exit_tree() -> void:
	Suspicion.enabled = false
	Quota.expected_interval = 0.0


func _on_caught() -> void:
	var controller: PlayerController = player.get_node("Controller")
	controller.enabled = false
	await hud.fade(1.0, 0.3)
	hud.show_card("CAUGHT\nDragged back to maintenance", 2.5)
	player.global_position = respawn.global_position
	player.velocity = Vector3.ZERO
	Suspicion.set_value(Security.aftermath_suspicion)
	await get_tree().create_timer(2.0).timeout
	controller.enabled = true
	await hud.fade(0.0, 1.0)
