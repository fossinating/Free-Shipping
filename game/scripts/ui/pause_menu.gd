class_name PauseMenu
extends Control
## Esc during play: pauses the game and offers a way out of anything that
## went wrong. Resume, reload the last maintenance bay backup, return to
## the title, and mouse sensitivity. Built in code like the title screen;
## the HUD adds it.

const TITLE := "res://scenes/ui/title.tscn"
## The sensitivity slider's range, in radians per pixel.
const MIN_SENSITIVITY := 0.0005
const MAX_SENSITIVITY := 0.006

## Esc does nothing while this controller has its dock panel open (Esc
## closes that instead).
var controller: PlayerController

var resume_button: Button
var reload_button: Button
var title_button: Button
var sensitivity: HSlider


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	resume_button = _button(column, "Resume", close)
	reload_button = _button(column, "Reload last backup", reload_backup)
	title_button = _button(column, "Return to title", return_to_title)
	column.add_child(Control.new())
	var label := Label.new()
	label.text = "Mouse sensitivity"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	sensitivity = HSlider.new()
	sensitivity.min_value = MIN_SENSITIVITY
	sensitivity.max_value = MAX_SENSITIVITY
	sensitivity.step = 0.0001
	sensitivity.custom_minimum_size = Vector2(260, 24)
	sensitivity.value_changed.connect(func(value: float) -> void:
		Settings.mouse_sensitivity = value)
	# Write the file once the slider is let go, not on every step.
	sensitivity.drag_ended.connect(func(_changed: bool) -> void: Settings.save())
	column.add_child(sensitivity)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		close()
	elif not (controller and controller.open_dock):
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	Settings.load_once()
	sensitivity.set_value_no_signal(Settings.mouse_sensitivity)
	reload_button.disabled = not _can_reload()
	reload_button.tooltip_text = "" if not reload_button.disabled \
		else "No backup in this area yet. Visit the maintenance bay."
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	resume_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	Settings.save()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Back to the last maintenance bay backup, as if continuing from the title.
func reload_backup() -> void:
	if not _can_reload():
		return
	_leave()
	SaveGame.load_game(get_tree())


func return_to_title() -> void:
	_leave()
	get_tree().change_scene_to_file(TITLE)


## Only backups of the level you're in: a save from another playthrough
## shouldn't yank you out of the opening shifts.
func _can_reload() -> bool:
	var scene := get_tree().current_scene
	return scene != null and SaveGame.read().get("scene", "") == scene.scene_file_path


func _leave() -> void:
	hide()
	get_tree().paused = false
	Quota.reset(0)
	Quota.expected_interval = 0.0
	Suspicion.reset()
	Security.reset()
	Dialogue.reset()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 44)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
