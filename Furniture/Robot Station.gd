extends StaticBody


export var start_open = false


func _ready():
	$"Occupied Light".set_surface_material(0, ($"Occupied Light".get_surface_material(0).duplicate(true)))
	$"Unoccupied Light".set_surface_material(0, ($"Unoccupied Light".get_surface_material(0).duplicate(true)))
	
	if start_open:
		$AnimationPlayer.play("Instant Open Door")
	else:
		$AnimationPlayer.play("RESET")


func _on_Door_Area_body_exited(body):
	if $"Door Area".get_overlapping_bodies().size() == 0 and body in $"Interior Area".get_overlapping_bodies() and body is Robot:
		$AnimationPlayer.play("Close Door")


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "Close Door":
		var found_robot = false
		for body in $"Interior Area".get_overlapping_bodies():
			if body is Robot:
				found_robot = true
			if body is Player:
				body.show_ui("Robot Station Menu")
				body.current_robot_station = self
		if !found_robot:
			$AnimationPlayer.play("Open Door")


func _on_AnimationPlayer_animation_started(anim_name):
	if anim_name == "Open Door":
		for body in $"Interior Area".get_overlapping_bodies():
			if body is Robot:
				body.rotation_degrees.y = self.rotation_degrees.y + 180
