extends Node
## Headless test runner. Run the scene, not the script, so autoloads load:
##   godot --headless --path game res://tests/run_tests.tscn -- [filter]
## Exits non-zero if any test fails.

## Give up if the whole suite takes longer than this (a test hung).
const TIMEOUT := 600.0


func _ready() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = TIMEOUT
	watchdog.one_shot = true
	watchdog.autostart = true
	watchdog.timeout.connect(func() -> void:
		print("\nTIMED OUT")
		get_tree().quit(2))
	add_child(watchdog)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]

	var passed := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_") or (filter != "" and not name.contains(filter)):
				continue
			var test: TestCase = script.new()
			test.tree = tree
			await test.call(name)
			test.cleanup()
			await tree.physics_frame
			if test.failures.is_empty():
				passed += 1
				print("  ok    %s.%s" % [file.get_basename(), name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [file.get_basename(), name])
				for failure in test.failures:
					print("          " + failure)
	print("\n%d passed, %d failed" % [passed, failed])
	tree.quit(1 if failed > 0 else 0)
