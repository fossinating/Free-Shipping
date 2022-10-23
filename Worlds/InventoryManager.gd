extends Spatial


var inventory = 0
var max_position_attempts = 10
export var inventory_goal = 5000
export (PackedScene)var item_table_scene
var item_table
onready var _1x1_box_scene = preload("res://Objects/Boxes/1x1 Box.tscn")
onready var _1x2_box_scene = preload("res://Objects/Boxes/1x2 Box.tscn")
onready var _2x1_box_scene = preload("res://Objects/Boxes/2x1 Box.tscn")
var rng = RandomNumberGenerator.new()
var thread = Thread.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	Globals.root = self
	item_table = item_table_scene.instance()
	rng.randomize()
	thread.start(self, "_box_spawn_thread", null)
	$Navigable/Elevator/AnimationPlayer.play("Elevator Open")

func _box_spawn_thread():
	for child in $Navigable/Objects.get_children():
		if child.name.begins_with("Shelf Row"):
			for shelf_stack in child.get_children():
				for shelf in shelf_stack.get_children():
					inventory += shelf.spawn_boxes()
			yield(get_tree(), "idle_frame")

func box_item():
	if item_table == null:
		item_table = item_table_scene.instance()
	var item = item_table.get_item()
	
	if item.size <= 1:
		# small box !
		var box = _1x1_box_scene.instance()
		box.item = item
		return box
	else:
		# large box
		var box = _2x1_box_scene.instance()
		box.item = item
		return box

func import_item():
	var box = box_item()
	if box.item.size <= 1:
		# small box !
		var location = null
		var attempts = 0
		while location == null and attempts < max_position_attempts:
			location = get_tree().get_nodes_in_group("inventory_location")[rng.randi_range(0, get_tree().get_nodes_in_group("inventory_location").size() - 1)]
			if location.inventory != null:
				location = null
		box.assigned_location = location
		location.inventory = box
		return box
	else:
		# large box
		var location = null
		var attempts = 0
		while location == null and attempts < max_position_attempts:
			location = get_tree().get_nodes_in_group("wide_inventory_location")[rng.randi_range(0, get_tree().get_nodes_in_group("inventory_location").size() - 1)]
			if location.inventory != null or location.neighbor.inventory != null:
				location = null
		box.assigned_location = location
		location.inventory = box
		location.neighbor.inventory = box
		return box


func export_box(box):
	# probably wont be able to implement this before the deadline unfortunately :(
	pass
