class_name Diagnostics
extends Node
## The maintenance bay's post-incident diagnostics: the scripted, safe
## introduction to suspicion. A maintenance robot (still under control)
## runs a list of tests and you have to answer like a loyal robot would.
## Abnormal answers raise suspicion, but the meter is capped below the top
## while this runs, so it can never turn into a lockdown.

## A test began (index into TESTS).
signal test_started(index: int)
## A test was answered. `normal` is whether it passed as loyal.
signal responded(index: int, normal: bool)
## All tests are done.
signal finished(anomalies: int)

enum Kind {
	## Pick the compliant answer (keys 1-3).
	CHOICE,
	## Don't move, grow or reach until the scan ends.
	STILL,
	## Press Click / F once the light turns green: not early, not late.
	REFLEX,
}

const TESTS: Array[Dictionary] = [
	{"kind": Kind.CHOICE, "normal": 0,
	 "prompt": "Diagnostic 1 of 4. State your designation and primary function.",
	 "options": ["\"FS-4471. I move packages. I meet quota.\"",
				 "\"I was... dreaming? There was a puddle.\"",
				 "\"Who's asking?\""]},
	{"kind": Kind.STILL, "seconds": 3.0,
	 "prompt": "Diagnostic 2 of 4. Sensor calibration. Remain completely still."},
	{"kind": Kind.REFLEX,
	 "prompt": "Diagnostic 3 of 4. Reflex check. Press Click / F when the light turns green. Not before."},
	{"kind": Kind.CHOICE, "normal": 0,
	 "prompt": "Diagnostic 4 of 4. Rate your job satisfaction from 1 to 3.",
	 "options": ["\"3. I love my job.\"",
				 "\"2. It's fine.\"",
				 "\"1. Why is the roof still leaking?\""]},
]

const REPLY_NORMAL := "Response nominal."
const REPLY_ABNORMAL := "Response abnormal. Anomaly logged."
const REPLY_MOVED := "Movement detected during calibration. Anomaly logged."
const REPLY_EARLY := "Premature response. Anomaly logged."
const REPLY_LATE := "No response. Anomaly logged."

## The robot being diagnosed.
@export var robot: RobotBody
@export var hud: Hud
## Suspicion added by each abnormal answer.
@export var anomaly_suspicion := 18.0
## Suspicion can't go above this while diagnostics run.
@export var safe_ceiling := 85.0
## Seconds between an answer and the next test.
@export var response_pause := 1.8
## Seconds after a test starts before movement counts against STILL.
@export var settle_time := 0.6
## Seconds before the REFLEX light turns green.
@export var reflex_delay := 2.5
## Seconds the light stays green.
@export var reflex_window := 1.2
## How far you can drift during STILL before it counts as moving.
@export var still_tolerance := 0.3

var running := false
var index := -1
var anomalies := 0
## Whether each finished test passed, in order.
var results: Array[bool] = []

var _timer := 0.0
var _pause := 0.0
var _waiting := false
var _anchor := Vector3.ZERO
var _anchor_extension := 0.0


func start() -> void:
	running = true
	index = -1
	anomalies = 0
	results.clear()
	Suspicion.ceiling = minf(Suspicion.ceiling, safe_ceiling)
	_next()


func get_test() -> Dictionary:
	return TESTS[index] if running and index >= 0 and index < TESTS.size() else {}


## Waiting for the player to respond to the current test.
func is_waiting() -> bool:
	return running and _waiting


## The REFLEX light is green.
func is_light_green() -> bool:
	return is_waiting() and get_test().kind == Kind.REFLEX and _timer >= reflex_delay


## Answer a CHOICE test with option `option` (0-based).
func answer(option: int) -> void:
	var test := get_test()
	if not is_waiting() or test.kind != Kind.CHOICE or option < 0 \
			or option >= test.options.size():
		return
	var normal: bool = option == test.normal
	_respond(normal, REPLY_NORMAL if normal else REPLY_ABNORMAL)


## Press for a REFLEX test.
func press() -> void:
	if not is_waiting() or get_test().kind != Kind.REFLEX:
		return
	if is_light_green():
		_respond(true, REPLY_NORMAL)
	else:
		_respond(false, REPLY_EARLY)


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_next()
		return
	if not _waiting:
		return
	_timer += delta
	var test := get_test()
	match test.kind:
		Kind.CHOICE:
			for i in test.options.size():
				if Input.is_action_just_pressed("choice_%d" % (i + 1)):
					answer(i)
					return
		Kind.STILL:
			if _timer < settle_time:
				_anchor = robot.global_position
				_anchor_extension = robot.extension
			elif _has_moved():
				_respond(false, REPLY_MOVED)
			elif _timer >= settle_time + test.seconds:
				_respond(true, REPLY_NORMAL)
		Kind.REFLEX:
			if Input.is_action_just_pressed("interact"):
				press()
			elif _timer >= reflex_delay + reflex_window:
				_respond(false, REPLY_LATE)
	if _waiting:
		_show_test()


func _has_moved() -> bool:
	var drift := robot.global_position - _anchor
	return Vector2(drift.x, drift.z).length() > still_tolerance \
		or absf(robot.extension - _anchor_extension) > 0.15 or robot.arm_extension > 0.2


func _next() -> void:
	index += 1
	if index >= TESTS.size():
		_finish()
		return
	_timer = 0.0
	_waiting = true
	Dialogue.play([{"speaker": &"maintenance", "text": TESTS[index].prompt}], true)
	_show_test()
	test_started.emit(index)


func _respond(normal: bool, reply: String) -> void:
	_waiting = false
	results.append(normal)
	if not normal:
		anomalies += 1
		Suspicion.add(anomaly_suspicion, "Diagnostic anomaly")
	if hud:
		hud.hide_choices()
	Dialogue.play([{"speaker": &"maintenance", "text": reply}], true)
	_pause = response_pause
	responded.emit(index, normal)


func _finish() -> void:
	running = false
	_waiting = false
	Suspicion.ceiling = Suspicion.MAX
	if hud:
		hud.hide_choices()
	finished.emit(anomalies)


## Puts the options, or the scan/light state, on the HUD.
func _show_test() -> void:
	if not hud:
		return
	var test := get_test()
	var lines: PackedStringArray = []
	match test.kind:
		Kind.CHOICE:
			for i in test.options.size():
				lines.append("%d   %s" % [i + 1, test.options[i]])
		Kind.STILL:
			var left := settle_time + float(test.seconds) - _timer
			lines.append("CALIBRATING  %.1f s   ·   don't move" % maxf(0.0, left))
		Kind.REFLEX:
			lines.append("●  GREEN  ·  PRESS NOW" if is_light_green() else "●  RED  ·  WAIT")
	hud.show_choices(lines, is_light_green())
