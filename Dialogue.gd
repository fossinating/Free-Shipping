extends PanelContainer


var time_passed = 0
var message
var proc_message = false
var time_per_char = 0.05
onready var show_tween = $Tween
onready var hide_tween = $Tween2
var tween_action
var timeout
signal message_done

func _ready():
	pass#set_process(false)


func hide_message():
	#set_process(false)
	hide_tween.interpolate_property(self, "rect_position:x", 1420, 1930, 1, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	hide_tween.start()
	tween_action = "hide"


func queue_message(name, message_, timeout:int = -1):
	$Timer.stop()
	self.message = message_
	show_tween.interpolate_property(self, "rect_position:x", 1930, 1420, 1, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	show_tween.start()
	$"MarginContainer/HBoxContainer/Name Label".text = name
	tween_action = "show"
	visible = true
	self.timeout = timeout

func _process(delta):
	if proc_message and message != null:
		time_passed += delta
		$MarginContainer/HBoxContainer/Label.text = message.substr(0, min(time_passed/time_per_char, message.length()))
		if time_passed/time_per_char > message.length():
			proc_message = false
			if timeout != -1:
				$Timer.wait_time = timeout
				$Timer.start()


func _on_Tween_tween_completed(object, _key):
	time_passed = 0
	proc_message = true


func _on_Timer_timeout():
	hide_message()


func _on_Tween2_tween_completed(object, key):
	message = null
	$MarginContainer/HBoxContainer/Label.text = ""
	visible = false
	emit_signal("message_done")
