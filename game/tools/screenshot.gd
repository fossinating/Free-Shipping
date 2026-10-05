extends Node
## Renders a scene and saves a screenshot, for checking visuals without
## opening the editor:
##   godot --path game res://tools/screenshot.tscn -- <scene> <out.png> [seconds] [eye] [target]
## eye and target are "x,y,z" and place a free camera instead of the scene's.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	add_child(load(args[0]).instantiate())
	var wait := float(args[2]) if args.size() > 2 else 1.0
	if args.size() > 4:
		var camera := Camera3D.new()
		add_child(camera)
		camera.look_at_from_position(_vec(args[3]), _vec(args[4]))
		camera.make_current()
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[1])
	get_tree().quit()


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
