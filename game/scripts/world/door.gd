class_name Door
extends AnimatableBody3D
## A door that slides up out of the way when its button is pressed (or a
## scanner lets you through), and back down when it closes.

@export var button: PushButton
@export var open_height := 3.4
@export var open_time := 1.2

var is_open := false

var _closed_y := 0.0
var _tween: Tween


func _ready() -> void:
	_closed_y = position.y
	if button:
		button.pressed.connect(open)


func open() -> void:
	if is_open:
		return
	is_open = true
	_slide_to(_closed_y + open_height)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_slide_to(_closed_y)


func _slide_to(y: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:y", y, open_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
