class_name Door
extends AnimatableBody3D
## A door that slides up out of the way when its button is pressed.

@export var button: PushButton
@export var open_height := 3.4
@export var open_time := 1.2

var is_open := false


func _ready() -> void:
	if button:
		button.pressed.connect(open)


func open() -> void:
	if is_open:
		return
	is_open = true
	create_tween().tween_property(self, "position:y", position.y + open_height, open_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
