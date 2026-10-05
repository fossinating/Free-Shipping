extends Node3D
## The opening: three controlled shifts, then the accident that frees you.

## After the accident, a delivery is still expected about this often.
const FREE_DELIVERY_INTERVAL := 90.0

@export var program: ControlProgram
@export var hud: Hud
@export var controller: PlayerController
@export var accident_site: AccidentSite
## Start at a later shift (0-based) when testing. -1 plays everything.
@export var debug_start_shift := -1
## Where you wake up after the accident. Empty stays here, free to roam.
@export_file("*.tscn") var next_level := "res://scenes/levels/warehouse.tscn"


func _ready() -> void:
	Suspicion.enabled = false
	controller.program = program
	program.accident.connect(_on_accident)
	program.start(maxi(debug_start_shift, 0))


func _on_accident() -> void:
	controller.enabled = false
	accident_site.trigger()
	await hud.fade(1.0, 0.08, Color.WHITE)
	await hud.fade(1.0, 0.2, Color.BLACK)
	GameState.set_flag(GameState.FLAG_FREED)
	await hud.show_card("CONTROL CHIP FAULT\nSIGNAL LOST", 3.0)
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
		return
	controller.enabled = true
	await hud.fade(0.0, 2.0)
	hud.show_card("Nobody is giving orders anymore.", 4.0)
	# From here on you have to pass as a loyal worker.
	Quota.reset(0)
	Quota.expected_interval = FREE_DELIVERY_INTERVAL
	Suspicion.reset()
	Suspicion.enabled = true
