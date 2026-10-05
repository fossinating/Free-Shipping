extends Node
## Default bindings. Actions are registered here instead of in project.godot
## so all bindings are readable in one place and tests can rely on them.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"grow": [KEY_E],
	"shrink": [KEY_Q],
	"extend_arms": [KEY_SHIFT],
	"interact": [KEY_F],
	"pause": [KEY_ESCAPE],
}

const MOUSE_BUTTONS := {
	"extend_arms": [MOUSE_BUTTON_RIGHT],
	"interact": [MOUSE_BUTTON_LEFT],
}


func _enter_tree() -> void:
	for action: String in KEYS:
		_ensure_action(action)
		for code: int in KEYS[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
	for action: String in MOUSE_BUTTONS:
		_ensure_action(action)
		for button: int in MOUSE_BUTTONS[action]:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = button
			InputMap.action_add_event(action, mouse)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
