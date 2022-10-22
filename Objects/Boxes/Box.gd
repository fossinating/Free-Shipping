extends Throwable


class_name Box

var assigned_location
var auto_place = false
var item

func _ready():
	if auto_place:
		global_transform.origin = assigned_location.global_transform.origin


func destroy():
	var item_drop = item.duplicate()
	get_tree().root.get_child(0).get_node("Objects").add_child(item_drop)
	item_drop.global_transform = global_transform
	.destroy()
