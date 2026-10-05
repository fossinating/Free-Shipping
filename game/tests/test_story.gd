extends TestCase
## Story: the dialogue queue, the maintenance bay's diagnostics, the signal
## meter, and finding Elle's radio.

const BAY := "res://scenes/levels/warehouse.tscn"
const OPENING := "res://scenes/levels/opening.tscn"

var level: Node3D
var robot: RobotBody
var controller: PlayerController
var diagnostics: Diagnostics
var receiver: SignalReceiver
var radio: Radio


func _start(skip_intro: bool) -> void:
	level = load(BAY).instantiate()
	level.skip_intro = skip_intro
	tree.root.add_child(level)
	_nodes.append(level)
	robot = level.get_node("Player")
	controller = level.get_node("Player/Controller")
	diagnostics = level.get_node("Diagnostics")
	receiver = level.get_node("SignalReceiver")
	radio = level.get_node("Radio")
	await physics_frames(3)


## Turns off everyone who could spot the player, for tests about the story.
func _quiet_security() -> void:
	for path in ["Security", "Guards", "Coworkers"]:
		level.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED


func _teleport(pos: Vector3, yaw := 0.0) -> void:
	robot.global_position = pos
	robot.rotation.y = yaw
	robot.facing_yaw = yaw
	robot.velocity = Vector3.ZERO
	await physics_frames(3)


## Waits (skipping any dialogue) until the diagnostics wait for an answer.
func _until_test(index: int, timeout := 10.0) -> void:
	var left := timeout
	while not (diagnostics.is_waiting() and diagnostics.index == index) and left > 0.0:
		if not diagnostics.running:
			Dialogue.skip()
		await physics_frames(6)
		left -= 0.1
	check(left > 0.0, "diagnostic %d started in time" % index)


## Waits (skipping dialogue) until the maintenance robot sends you out.
func _until_back_on_floor(timeout := 6.0) -> void:
	var left := timeout
	while not level.on_the_floor and left > 0.0:
		Dialogue.skip()
		await physics_frames(6)
		left -= 0.1
	check(left > 0.0, "sent back to the floor in time")


func _lines(count: int, speaker := &"elle") -> Array:
	var lines := []
	for i in count:
		lines.append({"speaker": speaker, "text": "Line %d of a test conversation." % i})
	return lines


# --- Dialogue ---

func test_dialogue_queues_types_and_advances() -> void:
	Dialogue.auto_advance = false
	var first := Dialogue.play(_lines(2))
	var second := Dialogue.play(_lines(1, &"maintenance"))
	check(Dialogue.current == first, "the first conversation plays first")
	check(not first.done and not second.done, "nothing is finished yet")
	Dialogue.update(0.1)
	check(Dialogue.get_visible_count() > 0 and not Dialogue.is_line_complete(),
		"lines type out over time")
	Dialogue.advance()
	check(Dialogue.is_line_complete() and first.index == 0,
		"advancing a typing line shows all of it first")
	Dialogue.advance()
	check(first.index == 1, "advancing again moves to the next line")
	Dialogue.update(10.0)
	check(first.index == 1, "with auto-advance off, a shown line stays up")
	Dialogue.advance()
	Dialogue.advance()
	check(first.done and not first.cut_short, "the first conversation played out")
	check(Dialogue.current == second, "the queued one starts right after")
	check(DialogueLines.speaker_name(Dialogue.get_speaker()) == "Maintenance Unit M-7",
		"each line has its speaker's name")
	Dialogue.skip()
	check(second.done and second.cut_short, "skip ends the conversation")
	check(not Dialogue.is_busy(), "and the queue is empty")


func test_dialogue_survives_skipping_and_interrupts() -> void:
	# Pressing on with nothing showing is harmless.
	Dialogue.advance()
	Dialogue.skip()
	Dialogue.update(1.0)
	check(not Dialogue.is_busy(), "advance and skip with nothing queued do nothing")

	var background := Dialogue.play(_lines(3))
	var queued := Dialogue.play(_lines(2))
	Dialogue.update(0.05)
	var urgent := Dialogue.play(_lines(1, &"maintenance"), true)
	check(background.done and background.cut_short, "an interrupt cuts the current one off")
	check(Dialogue.current == urgent and Dialogue.get_visible_count() == 0,
		"the interrupting line starts fresh")
	check(not queued.done, "what was queued behind is kept")

	# Interrupting from inside a finished handler doesn't tangle the queue.
	var follow_ups := []
	var follow_up := func(c: Conversation) -> void:
		if c == urgent:
			follow_ups.append(Dialogue.play(_lines(1), true))
	Dialogue.conversation_finished.connect(follow_up)
	Dialogue.skip()
	Dialogue.conversation_finished.disconnect(follow_up)
	check(follow_ups.size() == 1 and Dialogue.current == follow_ups[0],
		"a conversation queued while another ends plays next")

	# Mashing through everything ends cleanly.
	for i in 40:
		Dialogue.advance()
	check(not Dialogue.is_busy(), "mashing advance gets through every line")
	check(queued.done and follow_ups[0].done, "every conversation finished")
	# wait() on a finished conversation returns at once instead of hanging.
	await queued.wait()
	check(true, "waiting on a finished conversation doesn't hang")


func test_dialogue_auto_advance_and_input() -> void:
	Dialogue.auto_advance = true
	var talk := Dialogue.play(_lines(2))
	await seconds(1.0)
	check(talk.index == 0, "auto-advance gives a line time to be read")
	await seconds(Dialogue.get_auto_time() + 1.5)
	check(talk.index == 1, "then moves on by itself")
	Input.action_press("dialogue_skip")
	await physics_frames(2)
	Input.action_release("dialogue_skip")
	await physics_frames(2)
	check(talk.done and talk.cut_short, "the skip key ends the conversation")

	var next := Dialogue.play(_lines(1))
	Input.action_press("dialogue_advance")
	await physics_frames(2)
	Input.action_release("dialogue_advance")
	await physics_frames(1)
	check(not next.done and Dialogue.is_line_complete(), "the advance key finishes typing")
	Input.action_press("dialogue_auto")
	await physics_frames(2)
	Input.action_release("dialogue_auto")
	check(not Dialogue.auto_advance, "T toggles auto-advance")


func test_dialogue_data_is_valid() -> void:
	for id: StringName in DialogueLines.CONVERSATIONS:
		var lines := DialogueLines.get_lines(id)
		check(not lines.is_empty(), "%s has lines" % id)
		for line: Dictionary in lines:
			check(DialogueLines.SPEAKERS.has(line.speaker), "%s: unknown speaker %s"
				% [id, line.speaker])
			check(String(line.text).length() > 0, "%s: empty line" % id)
	var unknown := Dialogue.play(&"no_such_conversation")
	check(unknown.done and not Dialogue.is_busy(), "an unknown id finishes at once")
	var opening: Node = load(OPENING).instantiate()
	check(opening.next_level == BAY and ResourceLoader.exists(opening.next_level),
		"the accident leads to the warehouse (and its maintenance bay)")
	opening.free()


# --- The maintenance bay ---

func test_diagnostics_clean_run() -> void:
	await _start(false)
	check(not controller.enabled, "you wake up still")
	check(receiver.get_static() > 0.0 and not receiver.tracking,
		"faint static, but no signal meter yet")
	await _until_test(0)
	check(controller.enabled, "you can move freely by the first test")
	var door: Door = level.get_node("Geometry/BayDoor")
	check(not door.is_open, "the bay door stays shut during diagnostics")
	diagnostics.answer(0)
	await _until_test(1)
	check(receiver.get_static() >= 0.15, "the static gets noticeable")
	controller.enabled = false
	await seconds(diagnostics.settle_time + 3.3)
	check(diagnostics.results.size() == 2 and not diagnostics.results.has(false),
		"staying still passes calibration")
	await _until_test(2)
	await seconds(diagnostics.reflex_delay + 0.2)
	check(diagnostics.is_light_green(), "the light turns green")
	diagnostics.press()
	await _until_test(3)
	diagnostics.answer(0)
	await seconds(0.2)
	check(diagnostics.anomalies == 0 and Suspicion.value == 0.0,
		"loyal answers raise no suspicion")
	await _until_back_on_floor()
	check(GameState.has_flag(GameState.FLAG_DIAGNOSTICS_DONE), "the diagnostics are recorded")
	check(GameState.get_flag(GameState.FLAG_DIAGNOSTIC_ANOMALIES) == 0, "with no anomalies")
	check(door.is_open, "then you're sent back to work")
	check(receiver.tracking and Quota.expected_interval > 0.0,
		"the signal meter and the quota start")


func test_diagnostics_anomalies_raise_suspicion_but_never_lock_down() -> void:
	await _start(false)
	Suspicion.set_value(60.0)
	await _until_test(0)
	diagnostics.answer(1)
	check(Suspicion.value > 60.0, "an odd answer raises suspicion")
	await _until_test(1)
	controller.enabled = false
	await seconds(diagnostics.settle_time + 0.3)
	robot.global_position += Vector3(1.0, 0, 0)
	await physics_frames(3)
	check(diagnostics.results.back() == false, "moving during calibration is abnormal")
	await _until_test(2)
	diagnostics.press()
	check(diagnostics.results.back() == false, "pressing before green is abnormal")
	await _until_test(3)
	diagnostics.answer(2)
	await seconds(0.2)
	check(diagnostics.anomalies == 4, "every odd answer is logged")
	check(Suspicion.value <= diagnostics.safe_ceiling, "suspicion is capped during diagnostics")
	check(not Security.lockdown, "and it can't turn into a lockdown")
	await _until_back_on_floor()
	check(Suspicion.ceiling == Suspicion.MAX, "the cap is lifted afterwards")
	check(GameState.get_flag(GameState.FLAG_DIAGNOSTIC_ANOMALIES) == 4, "the anomalies are kept")
	check((level.get_node("Geometry/BayDoor") as Door).is_open, "you're still sent back to work")


func test_reflex_too_late_is_abnormal() -> void:
	await _start(false)
	controller.enabled = false
	await _until_test(0)
	diagnostics.answer(0)
	await _until_test(1)
	await _until_test(2)
	await seconds(diagnostics.reflex_delay + diagnostics.reflex_window + 0.2)
	check(diagnostics.results.size() == 3 and diagnostics.results[2] == false,
		"not pressing at all is abnormal")


func test_signal_meter_leads_to_the_radio() -> void:
	await _start(true)
	_quiet_security()
	check(receiver.tracking, "skipping the intro puts you on the floor")
	await _teleport(Vector3(-4, 0.05, 9))
	var at_station := receiver.get_raw_strength()
	await _teleport(Vector3(17, 0.05, -2))
	var at_electronics := receiver.get_raw_strength()
	await _teleport(Vector3(24.5, 0.05, -10), -PI / 2.0)
	var at_rack := receiver.get_raw_strength()
	check(at_station < at_electronics and at_electronics < at_rack,
		"the signal gets stronger toward the radio (%.2f < %.2f < %.2f)"
		% [at_station, at_electronics, at_rack])
	check(at_station < 0.2, "it's faint on your work route")
	await seconds(1.5)
	check(receiver.get_bars() >= 4, "the meter shows it (%d bars)" % receiver.get_bars())
	check(receiver.get_static() > 0.5, "so does the static")
	check(Dialogue.is_playing(&"static_faint") or Dialogue.is_playing(&"static_close"),
		"garbled bits of Elle come through")


func test_finding_the_radio_meets_elle() -> void:
	await _start(true)
	_quiet_security()
	controller.enabled = false
	# Standing at the returns rack isn't close enough: the radio is up top.
	await _teleport(Vector3(25.2, 0.05, -10), -PI / 2.0)
	await seconds(0.3)
	check(not radio.is_found, "the radio is out of reach from the floor")
	robot.extension_input = 1.0
	var left := 3.0
	while not radio.is_found and left > 0.0:
		await physics_frames(3)
		left -= 0.05
	robot.extension_input = 0.0
	check(radio.is_found, "growing up to the radio tunes in")
	check(GameState.has_flag(GameState.FLAG_MET_ELLE), "you've met Elle")
	check(Dialogue.current and Dialogue.current.id == &"elle_first_contact",
		"Elle introduces herself")
	check(not receiver.tracking, "the signal meter has done its job")
	Dialogue.skip()
	await physics_frames(3)
	Quota.record_delivery(null)
	check(Dialogue.is_playing(&"elle_back_to_work"), "a delivery afterwards gets a word from Elle")


func test_radio_waits_for_the_diagnostics() -> void:
	await _start(false)
	_quiet_security()
	check(not radio.listening, "the radio doesn't tune in before the diagnostics")
	robot.global_position = radio.global_position + Vector3(-0.5, -1.0, 0)
	await physics_frames(3)
	check(not radio.is_found and not GameState.has_flag(GameState.FLAG_MET_ELLE),
		"even right next to it")
