class_name TitleMenu
extends Control
## The title screen: Continue from the save (if there is one) or start a
## new game from the opening shifts.

@export_file("*.tscn") var opening := "res://scenes/levels/opening.tscn"

var continue_button: Button
var new_game_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.08, 0.09, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "FREE SHIPPING"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A warehouse robot breaks free of its programming."
	subtitle.modulate = Color(1, 1, 1, 0.7)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(Control.new())

	var save := SaveGame.read()
	continue_button = _button(column, "Continue", _on_continue)
	continue_button.disabled = save.is_empty()
	if not save.is_empty():
		continue_button.tooltip_text = _describe(save)
		var info := Label.new()
		info.text = _describe(save)
		info.modulate = Color(1, 1, 1, 0.6)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(info)
	new_game_button = _button(column, "New Game", _on_new_game)
	if OS.get_name() != "Web":
		_button(column, "Quit", func() -> void: get_tree().quit())
	(continue_button if not continue_button.disabled else new_game_button).grab_focus.call_deferred()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 44)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## "Clearance 1 · Maintenance Bay · wiped twice"
func _describe(save: Dictionary) -> String:
	var state: Dictionary = save.get("game_state", {})
	var parts: PackedStringArray = ["Clearance %d" % int(state.get("clearance", 0))]
	var zone: String = save.get("player", {}).get("zone", "")
	if zone != "":
		parts.append(zone)
	var wipes := int(state.get("wipes", 0))
	if wipes > 0:
		parts.append("wiped %d time%s" % [wipes, "" if wipes == 1 else "s"])
	return "  ·  ".join(parts)


func _on_continue() -> void:
	if not SaveGame.load_game(get_tree()):
		continue_button.disabled = true


## Starts over from the opening. The old save stays until you save again.
func _on_new_game() -> void:
	GameState.reset_items()
	GameState.reset_story()
	Quota.reset(0)
	Suspicion.reset()
	Security.reset()
	get_tree().change_scene_to_file(opening)
