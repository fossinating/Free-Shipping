extends PanelContainer


var time_passed = 0
var held_message
var message
var time_per_char = 0.05
onready var tween = $Tween
var tween_action
var timeout
signal message_done

func _ready():
	pass#set_process(false)


func hide_message():
	#set_process(false)
	tween.interpolate_property(self, "rect_position:x", 1520, 1930, 1, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	tween_action = "hide"


func queue_message(message_, timeout:int = -1):
	$Timer.stop()
	self.held_message = message_
	tween.interpolate_property(self, "rect_position:x", 1930, 1520, 1, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	tween_action = "show"
	visible = true
	self.timeout = timeout

func _process(delta):
	if message != null:
		time_passed += delta
		$HBoxContainer/Label.text = message.substr(0, min(time_passed/time_per_char, message.length()))
		if time_passed/time_per_char > message.length():
			#set_process(false)
			if timeout != -1:
				$Timer.wait_time = timeout
				$Timer.start()


func _on_Tween_tween_completed(_object, _key):
	if tween_action == "hide":
		message = null
		$HBoxContainer/Label.text = ""
		visible = false
		emit_signal("message_done")
	if tween_action == "show":
		time_passed = 0
		self.message = self.held_message
		#set_process(true)


func _on_Timer_timeout():
	hide_message()
