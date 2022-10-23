extends Boss


var target
var paper_scene = preload("res://Objects/Paper Projectile.tscn")


func _ready():
	if Globals.save.game_state.office_boss_beat:
		set_health(0)


func _physics_process(_delta):
	for body in $"Visible Area".get_overlapping_bodies():
		if body is Player:
			$RayCast.cast_to = body.global_transform.origin - $RayCast.global_transform.origin
			if $RayCast.get_collider() == body:
				target = body.global_transform.origin
				$Focus.start(0)
	if target != null:
		var altered_target = Vector3(target.x, $"Core Mesh".global_transform.origin.y, target.z)
		
		$"Core Mesh".look_at(altered_target, Vector3.UP)
		$"Core Mesh".rotation_degrees.y -= 90
		if $Firerate.is_stopped():
			$Firerate.start()

func _on_Firerate_timeout():
	var paper = paper_scene.instance()
	paper._owner = self
	#paper.get_node("CollisionShape").disabled = true
	$"Core Mesh/Projectile Spawn Location".look_at(target, Vector3.UP)
	Globals.root.get_node("Objects").add_child(paper)
	paper.active = true
	paper.add_collision_exception_with(self)
	paper.global_transform = $"Core Mesh/Projectile Spawn Location".global_transform
	paper.linear_velocity = 30 * $"Core Mesh/Projectile Spawn Location".global_transform.origin.direction_to(target)
	paper.linear_velocity.y += $"Core Mesh/Projectile Spawn Location".global_transform.origin.distance_to(target)/5

func _on_Focus_timeout():
	target = null
	$Firerate.stop()

func die():
	Globals.save.game_state.office_boss_beat = true
	$Firerate.stop()
	set_physics_process(false)
	.die()
