class_name Hud
extends CanvasLayer
## Control hints, context prompts, the quota, and control mode's task
## readout, denials and shift cards.

@export var controller: PlayerController
@export var program: ControlProgram

var _denied_time := 0.0

@onready var _prompt: Label = $Prompt
@onready var _status: Label = $Status
@onready var _quota: Label = $Quota
@onready var _objective: Label = $Objective
@onready var _denied: Label = $Denied
@onready var _card: Label = $Card
@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	_denied.hide()
	_card.hide()
	_objective.hide()
	if program:
		program.denied.connect(flash_denied)
		program.step_started.connect(_on_step_started)
		program.shift_started.connect(func(shift: Shift) -> void:
			var quota := "Quota: %d deliveries" % shift.quota if shift.quota > 0 else ""
			show_card("%s\n%s" % [shift.title.to_upper(), quota], 2.5))
		program.shift_finished.connect(func(shift: Shift) -> void:
			_objective.hide()
			show_card("%s COMPLETE\nPerformance: acceptable" % shift.title.to_upper(), 2.5))


func _process(delta: float) -> void:
	if _denied_time > 0.0:
		_denied_time -= delta
		_denied.modulate.a = clampf(_denied_time / 0.4, 0.0, 1.0)
		_denied.visible = _denied_time > 0.0
	if program and not program.active:
		_objective.hide()
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


func flash_denied(reason: String) -> void:
	_denied.text = "ACTION DENIED\n" + reason
	_denied.show()
	_denied_time = 1.6


## Shows big centered text for a while. Returns once it's hidden again.
func show_card(text: String, seconds: float) -> void:
	_card.text = text
	_card.show()
	await get_tree().create_timer(seconds).timeout
	if _card.text == text:
		_card.hide()


## Fades the screen to `alpha` of `color` over `seconds`.
func fade(alpha: float, seconds: float, color := Color.BLACK) -> void:
	color.a = _fade.color.a
	_fade.color = color
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


func _on_step_started(step: ShiftStep) -> void:
	_objective.text = "%s  ·  TASK\n%s" % [program.current_shift.title.to_upper(), step.instruction]
	_objective.show()
