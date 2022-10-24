extends RigidBody

var keycard_type


func _on_Area_body_entered(body):
	if body is Player:
		body.pickup_keycard(keycard_type)
		queue_free()
