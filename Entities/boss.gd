extends KinematicBody

class_name Boss

export var health = 2

func _ready():
	self.add_to_group("Damageable")

func set_health(health_):
	self.health = health_
	if health <= 0:
		die()

func damage(damage):
	set_health(health-damage)

func die():
	pass
