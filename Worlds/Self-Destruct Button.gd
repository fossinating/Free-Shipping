extends MeshInstance


signal pressed
var is_pressed = false


func trigger(player_ref):
	emit_signal("pressed")
	$AnimationPlayer.play("Press")
	player_ref.deactivate_action(button_action)
	is_pressed = true


var button_action = ConnectedAction.new("interact", "Press Self-Destruct Button", self)
func _on_Area_body_entered(body):
	if body is Player and not is_pressed:
		body.activate_action(button_action)


func _on_Area_body_exited(body):
	if body is Player:
		body.deactivate_action(button_action)
