extends Boss


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var max_rotation_rate = 60
var velocity = 30


var target = null
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	for body in $"Visible Area".get_overlapping_bodies():
		if body is Player:
			$RayCast.cast_to = (body.global_transform.origin - $RayCast.global_transform.origin)
			#print($RayCast.cast_to)
			$RayCast.rotation_degrees = -rotation_degrees
			if $RayCast.get_collider() == body:
				target = body.global_transform.origin
				$NavigationAgent.set_target_location(target)
				$Boredom.start()
	
	if target != null:
		var next_target = $NavigationAgent.get_next_location()
		$Head.look_at(next_target, Vector3.UP)
		$Head.rotation_degrees = Vector3(0, $Head.rotation_degrees.y - 90, 0)
		if abs($Head.rotation_degrees.y) > 180:
			$Head.rotation_degrees.y = (int($Head.rotation_degrees.y) + 360) % 360
		rotation_degrees.y -= clamp(int($Head.rotation_degrees.y) % 360, -max_rotation_rate*delta, max_rotation_rate*delta)
		$Head.look_at(next_target, Vector3.UP)
		$Head.rotation_degrees = Vector3(0, $Head.rotation_degrees.y + 90, 0)
		var move_direction = Vector3(0,0,-1).rotated(Vector3.UP, global_rotation.y + rad2deg(90)).normalized()
		$NavigationAgent.set_velocity(velocity*move_direction*delta)



func _on_NavigationAgent_velocity_computed(safe_velocity):
	move_and_collide(safe_velocity)


func _on_Attack__Area_body_entered(body):
	if body is Player:
		$AnimationPlayer.play("Ready Attack")


func _on_Attack__Area_body_exited(body):
	if body is Player:
		$AnimationPlayer.play("Unready Attack")


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "Ready Attack":
		$AnimationPlayer.play("Attack")

func die():
	var keycard_scene = preload("res://Objects/Keycard.tscn")
	var keycard = keycard_scene.instance()
	keycard.keycard_type = "kids"
	yield(get_tree(), "idle_frame")
	Globals.root.get_node("Objects").add_child(keycard)
	keycard.global_transform = global_transform
	keycard.global_transform.origin.y += 3
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	keycard.linear_velocity = Vector3(rng.randi_range(-5, 5), 5,rng.randi_range(-5, 5))
	Globals.save.game_state.kids_boss_beat = true
	set_physics_process(false)
	.die()


func _on_Area_body_entered(body):
	if body is Player:
		body.damage(0.5)
