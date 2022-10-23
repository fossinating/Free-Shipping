extends PanelContainer


var time_passed = 0
var message
var time_per_char = 0.05
onready var tween = $Tween
var tween_action

func _ready():
	set_process(false)


func hide_message():
	set_process(false)
	tween.interpolate_property(self, "rect_position:x", 1520, 1930, 1, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	tween_action = "hide"


func queue_message(message):
	self.message = message
	tween.interpolate_property(self, "rect_position:x", 1930, 1520, 1, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	tween_action = "show"
	visible = true

func _process(delta):
	time_passed += delta
	print(min(time_passed/time_per_char, message.length()))
	$HBoxContainer/Label.text = message.substr(0, min(time_passed/time_per_char, message.length()))
	if time_passed/time_per_char > message.length():
		set_process(false)


func _on_Tween_tween_completed(_object, _key):
	if tween_action == "hide":
		message = ""
		visible = false
	if tween_action == "show":
		time_passed = 0
		set_process(true)
