extends StaticBody


var elevator_exited = false

func _ready():
	$AnimationPlayer.play("Elevator Open")

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "Elevator Cycle" or anim_name == "Elevator Close":
		for body in $Area.get_overlapping_bodies():
			if body is Player:
				body.show_elevator_controls()
				return

func _on_Area_body_exited(body):
	if body is Player and !elevator_exited:
		$AnimationPlayer.play("Elevator Close")
		elevator_exited = true


var button_action = ConnectedAction.new("interact", "Press Elevator Button", self)


func trigger(player_ref):
	$AnimationPlayer.play("Elevator Cycle")
	player_ref.deactivate_action(button_action)


func _on_Button_Area_body_entered(body):
	if body is Player and not $AnimationPlayer.is_playing():
		body.activate_action(button_action)


func _on_Button_Area_body_exited(body):
	if body is Player:
		body.deactivate_action(button_action)
