extends Control


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		$"Pause Menu".visible = !$"Pause Menu".visible
		get_tree().paused = $"Pause Menu".visible
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if $"Pause Menu".visible else Input.MOUSE_MODE_CAPTURED)


func _on_Resume_Game_Button_pressed():
	$"Pause Menu".visible = false
	get_tree().paused = false


func _on_Quit_Game_Button_pressed():
	get_tree().quit()


func _on_Quit_To_Menu_Button_pressed():
	var _trash = get_tree().change_scene("res://Menus/Main Menu.tscn")
	get_tree().paused = false


func _on_Maintenance_Button_pressed():
	pass # Replace with function body.


func _on_Office_Supplies_pressed():
	pass # Replace with function body.


func _on_Kids_Toys_pressed():
	var _trash = get_tree().change_scene("res://Worlds/Kids Warehouse.tscn")


func _on_BEZOS_Button_pressed():
	pass # Replace with function body.

func show_elevator_controls():
	get_tree().paused = true
	$"Elevator Control/GridContainer/Kids Toys".disabled = !Globals.game_state.office_boss_beat
	$"Elevator Control/GridContainer/Kids Toys".disabled = !Globals.game_state.kids_boss_beat
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$"Elevator Control".visible = true
