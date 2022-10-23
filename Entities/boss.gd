extends KinematicBody

class_name Boss

export var health = 15

func _ready():
	self.add_to_group("Damageable")

func set_health(health_):
	if health_ <=0 and health > 0:
		die()
	self.health = health_
	if health_ < 5:
		$Smoke.emitting = true
		$Smoke.amount = 50 - health_*10

func damage(damage):
	if health > 0:
		$Spark.amount = 8*damage
		$Spark.emitting = true
	set_health(max(health-damage, 0))

func die():
	$"Constant Spark".emitting = true
