class_name TestCase
extends RefCounted
## Base class for tests. Methods named test_* are run by run_tests.gd and
## may await. Call the check helpers; the first failure is reported.

var tree: SceneTree
var failures: PackedStringArray = []
var _nodes: Array[Node] = []


## Adds a scene to the tree for this test; it is freed afterwards.
func spawn(scene_path: String) -> Node:
	var node: Node = load(scene_path).instantiate()
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func cleanup() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	for action in InputMap.get_actions():
		Input.action_release(action)
	Quota.reset(0)
	Quota.expected_interval = 0.0
	Suspicion.reset()
	Security.reset()
	GameState.reset_items()
	GameState.reset_story()
	Dialogue.reset()


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func seconds(time: float) -> void:
	await physics_frames(ceili(time * Engine.physics_ticks_per_second))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance,
		"%s (expected %.3f ± %.3f, got %.3f)" % [message, expected, tolerance, actual])
