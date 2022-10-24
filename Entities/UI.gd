extends Control


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		$"Pause Menu".visible = !$"Pause Menu".visible
		set_menu_mode($"Pause Menu".visible)


func _on_Resume_Game_Button_pressed():
	$"Pause Menu".visible = false
	get_tree().paused = false


func _on_Quit_Game_Button_pressed():
	get_tree().quit()


func _on_Quit_To_Menu_Button_pressed():
	var _trash = get_tree().change_scene("res://Menus/Main Menu.tscn")
	get_tree().paused = false


func _on_Maintenance_Button_pressed():
	get_tree().paused = false
	yield(get_tree().create_timer(0.2), "timeout")
	# TODO: make it so that everything in the elevator is persistent!
	var _trash = get_tree().change_scene("res://Worlds/Maintenance.tscn")


func _on_Office_Supplies_pressed():
	$"Elevator Control".visible = false
	yield(get_tree().create_timer(0.2), "timeout")
	var _trash = get_tree().change_scene("res://Worlds/Office Warehouse.tscn")


func _on_Kids_Toys_pressed():
	$"Elevator Control".visible = false
	yield(get_tree().create_timer(0.2), "timeout")
	var _trash = get_tree().change_scene("res://Worlds/Kids Warehouse.tscn")


func _on_BEZOS_Button_pressed():
	$"Elevator Control".visible = false
	yield(get_tree().create_timer(0.2), "timeout")
	var _trash = get_tree().change_scene("res://Worlds/Boss Room.tscn")

func show_elevator_controls():
	$"Elevator Control/GridContainer/Kids Toys".disabled = !Globals.save.game_state.office_boss_beat
	$"Elevator Control/GridContainer/BEZOS Button".disabled = !Globals.save.game_state.kids_boss_beat
	$"Elevator Control".visible = true

onready var player = get_node("../../..")
func _on_Robot_Station_Menu_visibility_changed():
	$"Robot Station Menu/GridContainer/Repair Button".disabled = player.health == player.max_health
	set_menu_mode($"Robot Station Menu".visible)


func _on_Robot_Station_Repair_Button_pressed():
	player.set_health(player.max_health)
	$"Robot Station Menu/GridContainer/Repair Button".disabled = true


func _on_Robot_Station_Save_Button_pressed():
	Globals.save.write_savegame()


func _on_Robot_Station_Exit_Button_pressed():
	$"Robot Station Menu".visible = false
	player.current_robot_station.get_node("AnimationPlayer").play("Open Door")

func set_menu_mode(value):
	get_tree().paused = value
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED)

func _on_Elevator_Control_visibility_changed():
	set_menu_mode($"Elevator Control".visible)
