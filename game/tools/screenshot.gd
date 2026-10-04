extends SceneTree
## Renders a scene and saves a screenshot, for checking visuals without
## opening the editor:
##   godot --path game -s res://tools/screenshot.gd -- <scene> <out.png> [seconds]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var controls: Node = load("res://scripts/controls.gd").new()
	root.add_child(controls)
	root.add_child(load(args[0]).instantiate())
	var wait := float(args[2]) if args.size() > 2 else 1.0
	await create_timer(wait).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[1])
	quit()
