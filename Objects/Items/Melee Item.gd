extends Item


export var melee_damage = 2


func attack():
	set_collision(false)
	$AnimationPlayer.play("Attack")
	$"Attack Hitbox/CollisionShape".disabled = false


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "Attack":
		$"Attack Hitbox/CollisionShape".disabled = true
		$CollisionShape.disabled = false
		for body in $"Attack Hitbox".get_overlapping_bodies():
			if body != holder and body.is_in_group("Damageable"):
				body.damage(melee_damage)
		
