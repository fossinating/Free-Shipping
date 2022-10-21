extends StaticBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var box_scene = preload("res://Objects/Boxes/1x1 Box.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	spawn($Spawn1)
	#spawn($Spawn2)
	#spawn($Spawn3)
	spawn($Spawn4)
	#spawn($Spawn5)
	#spawn($Spawn6)

func spawn(position):
	var box = box_scene.instance()
	get_tree().root.get_node("Warehouse/Objects").call_deferred("add_child", box)
	box.global_transform = position.global_transform

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
