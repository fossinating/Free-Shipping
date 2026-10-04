extends CanvasLayer
## Control hints plus a context prompt from the player controller.

@export var controller: PlayerController

@onready var _prompt: Label = $Prompt
@onready var _status: Label = $Status
@onready var _quota: Label = $Quota


func _process(_delta: float) -> void:
	if not controller:
		return
	var prompt := controller.get_prompt()
	_prompt.text = prompt
	_prompt.visible = prompt != ""
	_status.text = "Height %.1f m" % controller.robot.get_height()
	if Quota.target > 0:
		_quota.text = "Quota  %d / %d" % [Quota.delivered_count, Quota.target]
	else:
		_quota.text = "Delivered  %d" % Quota.delivered_count
