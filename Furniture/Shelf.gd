extends StaticBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var box_scene = preload("res://Objects/Boxes/1x1 Box.tscn")

# Called when the node enters the scene tree for the first time.
func spawn_boxes():
	var count = 0
	
	var narrow_placement_options = [$"Inventory Location",$"Inventory Location2",$"Inventory Location3",$"Inventory Location4", $"Inventory Location5", $"Inventory Location6"]
	var wide_placement_options = [$"Wide Inventory Location",$"Wide Inventory Location2",$"Wide Inventory Location3",$"Wide Inventory Location4"]
	for i in 1:
		var box = Globals.root.box_item()
		var placement_options = []
		if box.item.size <= 1:
			placement_options = narrow_placement_options
		else:
			placement_options = wide_placement_options
#		print("size: ", box.item.size)
#		print("placement_options", placement_options)
		if placement_options.size() == 0:
			box.queue_free()
			continue
		box.assigned_location = placement_options[Globals.root.rng.randi_range(0, placement_options.size() - 1)]
		
		if box.item.size <= 1:
			narrow_placement_options.erase(box.assigned_location)
		else:
			narrow_placement_options.erase(box.assigned_location.location1)
			narrow_placement_options.erase(box.assigned_location.location2)
			if box.assigned_location in [$"Wide Inventory Location", $"Wide Inventory Location2"]:
				wide_placement_options.erase($"Wide Inventory Location")
				wide_placement_options.erase($"Wide Inventory Location2")
			else:
				wide_placement_options.erase($"Wide Inventory Location3")
				wide_placement_options.erase($"Wide Inventory Location4")
#		print("wide placement:", wide_placement_options)
#		print("narrow placement:", narrow_placement_options)
		box.auto_place = true
		Globals.root.get_node("Objects").call_deferred("add_child", box)
#		print("called add child")
		count += 1
	return count

func spawn(position):
	var box = box_scene.instance()
	get_tree().root.get_node("Warehouse/Objects").call_deferred("add_child", box)
	box.global_transform = position.global_transform

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
