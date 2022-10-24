extends Robot

class_name Player


# Called when the node enters the scene tree for the first time.
func _ready():
	Globals.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_lookaround(false)
	activate_action(reach_action)
	if Globals.save.game_state.player_health == null:
		Globals.save.game_state.player_health = max_health
	elif Globals.save.game_state.player_health == -1337:
		Globals.save.game_state.player_health = max_health
	set_health(Globals.save.game_state.player_health)
	yield(get_tree(), "idle_frame")
	if Globals.first_load and Globals.root.name == "Maintenance":
		$"Core/Third-Person Camera/UI/Cover".visible = true
		Globals.first_load = false
		global_transform = $"../../Spawn Location".global_transform
		if Globals.save.dialogue_progress.intro_dialogue:
			tween.interpolate_property(
				$"Core/Third-Person Camera/UI/Cover", 
				"color", 
				$"Core/Third-Person Camera/UI/Cover".color, 
				Color(0, 0, 0, 0), 
				2, 
				Tween.TRANS_SINE,
				Tween.EASE_IN)
			tween.start()
		else:
			$"Core/Third-Person Camera/UI/Cover".color.a = 1
	else:
		$"Core/Third-Person Camera/UI/Cover".color.a = 0


var arms_out = false
var lookaround = false
var throwing = false
var throw_charge = 0.0
export var min_throw_charge := 20.0
export var max_throw_charge := 60.0
export var throw_charge_rate := 20.0
var current_robot_station = null

func _physics_process(delta):
	#var rotation_vel = (Input.get_action_strength("movement_left") - Input.get_action_strength("movement_right")) * rotation_speed
	
	#robot.rotation_degrees.y += rotation_vel * delta
	
	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_action_strength("movement_right") - Input.get_action_strength("movement_left")
	move_direction.z = Input.get_action_strength("movement_back") - Input.get_action_strength("movement_forward")
	move_direction = move_direction.rotated(Vector3.UP, global_rotation.y).normalized()
	move_in_direction(move_direction, delta)
	
	var ext_vel = 0
	if Input.is_action_pressed("extend"):
		ext_vel += extension_speed
	if Input.is_action_pressed("retract"):
		ext_vel -= extension_speed
	extend(ext_vel*delta)
	# make third person toggleable
	var toggle_lookaround = true
	if toggle_lookaround:
		if Input.is_action_just_pressed("lookaround"):
			set_lookaround(!lookaround)
	else:
		if Input.is_action_just_released("lookaround"):
			set_lookaround(true)
		if Input.is_action_just_pressed("lookaround"):
			set_lookaround(false)
	if Input.is_action_just_pressed("reach") and $AnimationPlayer.current_animation != "ArmsOut" and held_item == null:
		arms_out()
	if Input.is_action_just_released("reach") and $AnimationPlayer.current_animation != "ArmsIn" and held_item == null:
		arms_in()
	if Input.is_action_just_pressed("interact"):
		if keybind_actions.has("interact") and keybind_actions["interact"].size() > 0:
			var action = keybind_actions["interact"].back()
			if action == pickup_item_action:
				pickup_item()
			elif action == drop_action:
				drop()
			elif action == pickup_box_action:
				for node in $"Core/Right Arm Root/Pickup Area".get_overlapping_bodies():
					if node is Box:
						pickup_box(node)
						deactivate_action(pickup_box_action)
						break
			elif action is ConnectedAction:
				action.trigger(self)
	if Input.is_action_just_pressed("attack"):
		if keybind_actions.has("attack") and keybind_actions["attack"].size() > 0:
			var action = keybind_actions["attack"].back()
			if action == attack_action:
				if held_item is Item:
					held_item.attack()
	if Input.is_action_just_pressed("throw") and held_item != null:
		deactivate_action(drop_action)
		throwing = true
		throw_charge = min_throw_charge
	if Input.is_action_pressed("throw") and throwing:
		throw_charge = min(throw_charge + delta*throw_charge_rate, max_throw_charge)
	if Input.is_action_just_released("throw") and throwing:
		held_item.linear_velocity = _velocity
		held_item.throw(-throw_charge*Vector3(0, 0, 1).rotated(Vector3(1,0,0), max(0, camera_manager.rotation.x)).rotated(Vector3.UP, global_rotation.y).normalized())
		set_held_item(null)
		throwing = false
		$AnimationPlayer.play("RESET")
		arms_out = false

var attack_action = Action.new("attack", "Attack")
var throw_action = Action.new("throw", "Throw")
var reach_action = Action.new("reach", "Reach")
var drop_action = Action.new("interact", "Drop")
func set_held_item(item):
	if item == null:
		activate_action(reach_action)
		deactivate_action(attack_action)
		deactivate_action(throw_action)
		deactivate_action(drop_action)
	if item != null:
		deactivate_action(reach_action)
		if item is Item:
			activate_action(attack_action)
		activate_action(throw_action)
		activate_action(drop_action)
	.set_held_item(item)


var keybind_actions = {}


func activate_action(action):
	if not keybind_actions.has(action.keybind):
		keybind_actions[action.keybind] = [action]
	else:
		keybind_actions[action.keybind].append(action)
	var keybind_display = get_node("Core/Third-Person Camera/UI/Temporary Controls/MarginContainer/VBoxContainer/" + action.keybind)
	keybind_display.get_node("Label").text = action.description
	keybind_display.visible = true

func deactivate_action(action):
	if keybind_actions.has(action.keybind):
		keybind_actions[action.keybind].erase(action)
		var keybind_display = get_node("Core/Third-Person Camera/UI/Temporary Controls/MarginContainer/VBoxContainer/" + action.keybind)
		if keybind_actions[action.keybind].size() > 0:
			keybind_display.get_node("Label").text = keybind_actions[action.keybind].back().description
		else:
			keybind_display.visible = false

func set_lookaround(_lookaround):
	lookaround = _lookaround
	if _lookaround:
		$"Core/Third-Person Camera/ClippedCamera".translation.z = 5
		$"Core/Core Mesh".visible = true
		$"Legs".visible = true
	else:
		$"Core/Third-Person Camera/ClippedCamera".translation.z = 0
		camera_manager.rotation_degrees.y = 0
		$"Core/Core Mesh".visible = false
		$"Legs".visible = false

var mouse_sensitivity = 0.15
var camera_anglev = 0
onready var camera_manager = $"Core/Third-Person Camera"

func _input(event):
	if event is InputEventMouseMotion:
		camera_manager.rotation_degrees.x -= event.relative.y * mouse_sensitivity
		camera_manager.rotation_degrees.x = clamp(camera_manager.rotation_degrees.x, -90.0, 60)
		
		if lookaround:
			camera_manager.rotation_degrees.y -= event.relative.x * mouse_sensitivity
			camera_manager.rotation_degrees.y = wrapf(camera_manager.rotation_degrees.y, 0.0, 360.0)
		else:
			rotation_degrees.y -= event.relative.x * mouse_sensitivity
			rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)


func _on_Item_Pickup_Area_body_entered(body):
	if held_item == null and body is Item and body.holder == null:
		item_pickup_test()


func _on_Item_Pickup_Area_body_exited(body):
	if held_item == null and body is Item and body.holder == null:
		item_pickup_test()

var pickup_item_action = Action.new("interact", "Pickup Item")

func item_pickup_test():
	for body in $"Core/Item Pickup Area".get_overlapping_bodies():
		if body is Item and body.holder == null:
			activate_action(pickup_item_action)
			return
	deactivate_action(pickup_item_action)

func pickup_item():
	for body in $"Core/Item Pickup Area".get_overlapping_bodies():
		if body is Item and body.holder == null:
			deactivate_action(pickup_item_action)
			body.holder = self
			$AnimationPlayer.play("RightArmOut")
			set_held_item(body)
			body.get_parent().remove_child(body)
			$"Core/Right Arm Root/Item Holder".add_child(body)
			body.set_collision(false)
			body.transform.origin = Vector3(0,0,0)
			body.rotation = Vector3(0,0,0)
			body.mode = RigidBody.MODE_STATIC
			return
	
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "RightArmOut":
		pass
	elif anim_name == "ArmsIn":
		arms_out = false
	elif anim_name == "ArmsOut":
		arms_out = true
	._on_AnimationPlayer_animation_finished(anim_name)
		


func _on_Pickup_Area_body_entered(body):
	if held_item == null and body is Box and body.holder == null:
		test_box_pickup()


func _on_Pickup_Area_body_exited(body):
	if held_item == null and body is Box and body.holder == null:
		test_box_pickup()

var pickup_box_action = Action.new("interact", "Pick Up Box")
func test_box_pickup():
	for body in $"Core/Right Arm Root/Pickup Area".get_overlapping_bodies():
		if body is Box and body.holder == null:
			activate_action(pickup_box_action)
			return
	deactivate_action(pickup_box_action)

func set_health(health):
	$"Core/Third-Person Camera/UI/Health Bar".value = health
	Globals.save.game_state.player_health = health
	.set_health(health)

func die():
	set_health(max_health)
	var _trash = get_tree().change_scene("res://Menus/Main Menu.tscn")

func show_elevator_controls():
	$"Core/Third-Person Camera/UI".show_elevator_controls()

func show_ui(ui):
	get_node("Core/Third-Person Camera/UI/" + ui).visible = true

var keycard_inventory = []
func pickup_keycard(keycard):
	keycard_inventory.append(keycard)
	if keycard == "office":
		Globals.save.game_state.office_boss_beat = true
	if keycard == "kids":
		Globals.save.game_state.kids_boss_beat = true
