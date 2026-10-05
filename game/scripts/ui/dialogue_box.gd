class_name DialogueBox
extends PanelContainer
## Shows the `Dialogue` queue's current line, typed out under the speaker's
## name, and a list of choices when something asks for an answer. Built in
## code like the dock panel; the HUD adds it.

var _name: Label
var _text: Label
var _hint: Label
var _choices: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -340.0
	offset_right = 340.0
	offset_top = -176.0
	offset_bottom = -160.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_name = _label(20)
	column.add_child(_name)
	_text = _label(20)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(640, 0)
	column.add_child(_text)
	_choices = _label(20)
	_choices.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	column.add_child(_choices)
	_hint = _label(14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint)
	hide_choices()


func _process(_delta: float) -> void:
	var speaking := Dialogue.is_busy()
	_name.visible = speaking and DialogueLines.speaker_name(Dialogue.get_speaker()) != ""
	_text.visible = speaking
	_hint.visible = speaking
	visible = speaking or _choices.visible
	if not speaking:
		return
	var speaker := Dialogue.get_speaker()
	_name.text = DialogueLines.speaker_name(speaker).to_upper()
	_name.add_theme_color_override("font_color", DialogueLines.speaker_color(speaker))
	_text.text = Dialogue.get_text()
	_text.visible_characters = Dialogue.get_visible_count()
	_text.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8)
		if speaker == &"static" else Color.WHITE)
	_hint.text = "Space  next   ·   Backspace  skip   ·   T  auto-advance: %s" \
		% ("on" if Dialogue.auto_advance else "off")


func show_choices(lines: PackedStringArray, highlight := false) -> void:
	_choices.text = "\n".join(lines)
	_choices.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.5) if highlight else Color(1, 0.85, 0.4))
	_choices.show()
	show()


func hide_choices() -> void:
	_choices.hide()


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label
