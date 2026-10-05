class_name AccidentSite
extends Node3D
## The leaking roof over exposed wiring that fries the control chip.

@onready var _sparks: CPUParticles3D = $Sparks
@onready var _flash: OmniLight3D = $Flash


func _ready() -> void:
	_flash.light_energy = 0.0


## The big shock when a robot walks into the puddle.
func trigger() -> void:
	_sparks.amount = 160
	_sparks.initial_velocity_max = 9.0
	_sparks.restart()
	var tween := create_tween()
	tween.tween_property(_flash, "light_energy", 12.0, 0.05)
	tween.tween_property(_flash, "light_energy", 0.0, 0.6)
