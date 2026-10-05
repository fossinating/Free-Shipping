class_name Hud
extends CanvasLayer
## Control hints, context prompts, the quota, control mode's task readout,
## denials and shift cards, the inventory, the dock panel, dialogue and
## story objectives, and the signal meter and static from your fried chip.

@export var controller: PlayerController
@export var program: ControlProgram
## Your fried control chip, once there is one.
@export var receiver: SignalReceiver

var _denied_time := 0.0
var _notice_time := 0.0
var _dock_panel: DockPanel
var _dialogue_box: DialogueBox
## A story objective (outside control mode) is showing.
var _story_objective := false

@onready var _prompt: Label = $Prompt
@onready var _status: Label = $Status
@onready var _quota: Label = $Quota
@onready var _objective: Label = $Objective
@onready var _denied: Label = $Denied
@onready var _card: Label = $Card
@onready var _fade: ColorRect = $Fade
@onready var _suspicion: Control = $Suspicion
@onready var _meter: ProgressBar = $Suspicion/Meter
@onready var _suspicion_status: Label = $Suspicion/Status
@onready var _lockdown: Label = $Lockdown
@onready var _inventory: Label = $Inventory
@onready var _notice: Label = $Notice
@onready var _static: ColorRect = $Static
@onready var _signal: Label = $Signal


func _ready() -> void:
	_denied.hide()
	_card.hide()
	_objective.hide()
	_notice.hide()
	_dock_panel = DockPanel.new()
	add_child(_dock_panel)
	_dialogue_box = DialogueBox.new()
	add_child(_dialogue_box)
	# The fade covers everything but the cards.
	move_child(_fade, -1)
	move_child(_card, -1)
	if controller:
		controller.notice.connect(show_notice)
	GameState.recipe_revealed.connect(func(recipe: int) -> void:
		var text := "New recipe: " + ItemCatalog.describe_recipe(recipe)
		# Several recipes revealed at once stack up.
		if _notice_time > 0.0 and _notice.text.begins_with("New recipe"):
			text = _notice.text + "\n" + text
		show_notice(text))
	GameState.upgrade_installed.connect(func(id: StringName) -> void:
		show_card("UPGRADE INSTALLED\n" + ItemCatalog.name_of(id), 2.0))
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
	if _notice_time > 0.0:
		_notice_time -= delta
		_notice.modulate.a = clampf(_notice_time / 0.5, 0.0, 1.0)
		_notice.visible = _notice_time > 0.0
	if program and not program.active and not _story_objective:
		_objective.hide()
	_update_suspicion()
	_update_signal()
	if not controller:
		return
	_update_items()
	var prompt := controller.get_prompt()
	_prompt.text = prompt
	_prompt.visible = prompt != ""
	_status.text = "Height %.1f m" % controller.robot.get_height()
	if Suspicion.enabled:
		_status.text += "  ·  Badge: clearance %d" % GameState.clearance
	if Quota.target > 0:
		_quota.text = "Quota  %d / %d" % [Quota.delivered_count, Quota.target]
	else:
		_quota.text = "Delivered  %d" % Quota.delivered_count


func _update_suspicion() -> void:
	_suspicion.visible = Suspicion.enabled
	if not Suspicion.enabled:
		return
	_meter.max_value = Suspicion.MAX
	_meter.value = Suspicion.value
	var fill := _meter.get_theme_stylebox("fill") as StyleBoxFlat
	var t := Suspicion.value / Suspicion.MAX
	fill.bg_color = Color(0.4, 0.85, 0.4).lerp(Color(1.0, 0.25, 0.2), t)
	var status: PackedStringArray = []
	if Suspicion.is_alarmed():
		status.append("SEEN: " + Suspicion.last_reason)
	elif Suspicion.is_watched():
		status.append("Watched")
	if Suspicion.is_under_review():
		status.append("UNDER REVIEW: behind on deliveries")
	var player := controller.robot if controller else null
	if player and HidingSpot.is_hidden(player):
		status.append("Hidden")
	_suspicion_status.text = "\n".join(status)
	_lockdown.visible = Security.lockdown
	if Security.lockdown:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		_lockdown.modulate.a = pulse
		_lockdown.text = "LOCKDOWN  %d%%\nHide, or blend back in by carrying stock" \
			% roundi(Security.get_lockdown_progress() * 100.0)


func _update_items() -> void:
	var dock := controller.open_dock
	if dock != _dock_panel.dock:
		if dock:
			_dock_panel.open(dock, controller.inventory)
		else:
			_dock_panel.close()
	var inventory := controller.inventory
	_inventory.visible = inventory != null and not (program and program.active)
	if not _inventory.visible:
		return
	var lines: PackedStringArray = ["INVENTORY  (Tab to cycle)"]
	for i in inventory.slots.size():
		var state := inventory.slots[i]
		var text := state.get_label() if state else "—"
		var marker := "▶ " if i == inventory.selected else "   "
		if state and i == inventory.selected and state.is_contraband():
			text += "  [VISIBLE]"
		lines.append("%s%d  %s" % [marker, i + 1, text])
	if inventory.selected < 0:
		lines.append("▶ Holstered")
	_inventory.text = "\n".join(lines)


func _update_signal() -> void:
	var level := receiver.get_static() if receiver else 0.0
	(_static.material as ShaderMaterial).set_shader_parameter("intensity", level)
	_static.visible = level > 0.001
	_signal.visible = receiver != null and receiver.tracking
	if _signal.visible:
		var bars := receiver.get_bars()
		var meter: PackedStringArray = []
		for i in SignalReceiver.BARS:
			meter.append("|" if i < bars else "·")
		_signal.text = "SIGNAL  " + " ".join(meter)


## A story objective at the top of the screen, until hide_objective().
func show_objective(text: String) -> void:
	_story_objective = true
	_objective.text = "OBJECTIVE\n" + text
	_objective.show()


func hide_objective() -> void:
	_story_objective = false
	_objective.hide()


## Answers (or a test's status) under the dialogue box.
func show_choices(lines: PackedStringArray, highlight := false) -> void:
	_dialogue_box.show_choices(lines, highlight)


func hide_choices() -> void:
	_dialogue_box.hide_choices()


## A short line above the prompt that fades out.
func show_notice(text: String) -> void:
	_notice.text = text
	_notice.show()
	_notice_time = 2.5


func flash_denied(reason: String, title := "ACTION DENIED") -> void:
	_denied.text = title + "\n" + reason
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
