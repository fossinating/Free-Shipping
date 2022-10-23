extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	load_settings()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


onready var _active_menu = $"UI/Menus/Main Menu"

func switch_menu(to_node):
	var _animation_time = 0.5
	var tween = $Tween
	tween.interpolate_property(
		_active_menu,
		"rect_position:x",
		_active_menu.rect_position.x,
		2000,
		_animation_time,
		tween.TRANS_SINE,
		# Easing out means we start fast and slow down as we reach the target value.
		tween.EASE_IN_OUT
	)
	tween.interpolate_property(
		to_node,
		"rect_position:x",
		to_node.rect_position.x,
		0,
		_animation_time,
		tween.TRANS_SINE,
		# Easing out means we start fast and slow down as we reach the target value.
		tween.EASE_IN_OUT
	)
	_active_menu = to_node
	
	tween.start()


func _on_Level_Select_pressed():
	var _trash = get_tree().change_scene("res://Worlds/Office Warehouse.tscn")


func _on_Settings_pressed():
	switch_menu($"UI/Menus/Settings Menu")


func _on_Credits_pressed():
	switch_menu($"UI/Menus/Credits")


func _on_Back_to_Main_Menu_pressed():
	switch_menu($"UI/Menus/Main Menu")


func _on_Quit_to_Desktop_pressed():
	get_tree().quit()

var switch_to = "res://Menus/Main Menu.tscn"

func play_level(level):
	switch_to = "res://Rooms/Level_" + str(level) + ".tscn"
	var tween = $Tween
	tween.interpolate_property(
		$UI,
		"modulate:a",
		$UI.modulate.a,
		0, # final value
		0.4, # time taken
		tween.TRANS_SINE,
		tween.EASE_IN
	)
	tween.interpolate_property(
		$"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera",
		"global_transform:origin",
		$"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera".global_transform.origin,
		$"CanvasLayer/ViewportContainer/Viewport/Menu Room/Slime".global_transform.origin,
		1.6, # time taken
		tween.TRANS_SINE,
		# Easing out means we start fast and slow down as we reach the target value.
		tween.EASE_OUT
	)
	var original_basis = $"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera".global_transform.basis
	$"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera".look_at($"CanvasLayer/ViewportContainer/Viewport/Menu Room/Slime".global_transform.origin, Vector3.UP)
	var basis = $"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera".global_transform.basis
	$"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera".global_transform.basis = original_basis
	tween.interpolate_property(
		$"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera",
		"global_transform:basis",
		original_basis,
		basis,
		1.6,
		tween.TRANS_SINE,
		# Easing out means we start fast and slow down as we reach the target value.
		tween.EASE_OUT
	)
	tween.interpolate_property(
		$CanvasLayer/CanvasModulate,
		"color",
		$CanvasLayer/CanvasModulate.color,
		Color(0.0, 0.0, 0.0), # final_val
		1.2,
		tween.TRANS_SINE,
		tween.EASE_OUT
	)
	
	tween.start()


func _on_Tween_tween_completed(object, key):
	if object == $"CanvasLayer/ViewportContainer/Viewport/Menu Room/Camera" and key == ":global_transform:origin":
		var _trash = get_tree().change_scene(switch_to)

onready var _master_bus := AudioServer.get_bus_index("Master")
onready var _music_bus := AudioServer.get_bus_index("Music")
onready var _sounds_bus := AudioServer.get_bus_index("Sounds")

func _on_Master_Volume_Slider_value_changed(value):
	AudioServer.set_bus_volume_db(_master_bus, linear2db(value))


func _on_Music_Volume_Slider_value_changed(value):
	AudioServer.set_bus_volume_db(_music_bus, linear2db(value))


func _on_Sounds_Volume_Slider_value_changed(value):
	AudioServer.set_bus_volume_db(_sounds_bus, linear2db(value))


func get_or_default(file, default):
	var value = file.get_var()
	if value == null:
		return default
	else:
		return value

var settings_file = "user://settings.save"

func load_settings():
	var f = File.new()
	if f.file_exists(settings_file):
		f.open(settings_file, File.READ)
		$"UI/Menus/Settings Menu/VBoxContainer/Master Volume/Master Volume Slider".value = get_or_default(f, 1.0)
		$"UI/Menus/Settings Menu/VBoxContainer/Music Volume/Music Volume Slider".value = get_or_default(f, 1.0)
		$"UI/Menus/Settings Menu/VBoxContainer/Sounds Volume/Sounds Volume Slider".value = get_or_default(f, 1.0)
		$"UI/Menus/Settings Menu/VBoxContainer/Show Hints/Show Hints Checkbox".pressed = get_or_default(f, $"UI/Menus/Settings Menu/VBoxContainer/Performance Mode/Performance Mode Checkbox".pressed)
		$"UI/Menus/Settings Menu/VBoxContainer/Performance Mode/Performance Mode Checkbox".pressed = get_or_default(f, $"UI/Menus/Settings Menu/VBoxContainer/Performance Mode/Performance Mode Checkbox".pressed)
		f.close()
	else:
		$"UI/Menus/Settings Menu/VBoxContainer/Master Volume/Master Volume Slider".value = db2linear(AudioServer.get_bus_volume_db(_master_bus))
		$"UI/Menus/Settings Menu/VBoxContainer/Music Volume/Music Volume Slider".value = db2linear(AudioServer.get_bus_volume_db(_music_bus))
		$"UI/Menus/Settings Menu/VBoxContainer/Sounds Volume/Sounds Volume Slider".value = db2linear(AudioServer.get_bus_volume_db(_sounds_bus))
		
		
func save_settings():
	var f = File.new()
	f.open(settings_file, File.WRITE)
	f.store_var($"UI/Menus/Settings Menu/VBoxContainer/Master Volume/Master Volume Slider".value)
	f.store_var($"UI/Menus/Settings Menu/VBoxContainer/Music Volume/Music Volume Slider".value)
	f.store_var($"UI/Menus/Settings Menu/VBoxContainer/Sounds Volume/Sounds Volume Slider".value)
	f.store_var($"UI/Menus/Settings Menu/VBoxContainer/Show Hints/Show Hints Checkbox".pressed)
	f.store_var($"UI/Menus/Settings Menu/VBoxContainer/Performance Mode/Performance Mode Checkbox".pressed)
	f.close()
