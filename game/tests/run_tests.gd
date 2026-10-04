extends SceneTree
## Headless test runner:
##   godot --headless --path game -s res://tests/run_tests.gd [-- filter]
## Exits non-zero if any test fails.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Autoloads are not loaded for -s scripts, so register them by hand.
	var controls: Node = load("res://scripts/controls.gd").new()
	controls.name = "Controls"
	root.add_child(controls)

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
			test.tree = self
			await test.call(name)
			test.cleanup()
			await physics_frame
			if test.failures.is_empty():
				passed += 1
				print("  ok    %s.%s" % [file.get_basename(), name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [file.get_basename(), name])
				for failure in test.failures:
					print("          " + failure)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
