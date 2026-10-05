extends Node
## The dialogue queue (autoload `Dialogue`). Anything can queue lines with
## `play()`; the HUD's dialogue box shows them one at a time, typed out,
## under the speaker's name.
##
## The jam version broke when a new message arrived, or the player moved
## on, before the last one was done. Here:
## - conversations queue instead of overwriting each other,
## - an interrupting conversation cuts the current one off cleanly,
## - advancing or skipping at any moment (even with nothing showing) is safe,
## - every conversation reports when it's over, however it ended.

signal line_started(line: Dictionary)
signal conversation_started(conversation: Conversation)
signal conversation_finished(conversation: Conversation)

## Typing speed.
@export var chars_per_second := 55.0
## With auto-advance on, a fully shown line stays up this long...
@export var auto_delay := 1.2
## ...plus this much per character, so long lines stay up longer.
@export var auto_delay_per_char := 0.035

## Move on by itself after each line. Advancing early still works.
var auto_advance := true
## The conversation showing now, or null.
var current: Conversation

var _queue: Array[Conversation] = []
## Characters of the current line shown so far.
var _shown := 0.0
## Seconds the current line has been fully shown.
var _hold := 0.0


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("dialogue_advance"):
		advance()
	if Input.is_action_just_pressed("dialogue_skip"):
		skip()
	if Input.is_action_just_pressed("dialogue_auto"):
		auto_advance = not auto_advance


func _process(delta: float) -> void:
	update(delta)


## Queues a conversation: an id from DialogueLines, or an array of line
## dictionaries ({"speaker": &"elle", "text": "..."}). With `interrupt`,
## it cuts off whatever is showing and plays right away.
func play(what: Variant, interrupt := false) -> Conversation:
	var conversation: Conversation
	if what is Array:
		conversation = Conversation.new(&"", what)
	else:
		conversation = Conversation.new(StringName(what), DialogueLines.get_lines(StringName(what)))
	if conversation.lines.is_empty():
		push_warning("Dialogue: nothing to say for %s" % [what])
		conversation._finish(false)
		return conversation
	if interrupt:
		_queue.push_front(conversation)
		if current:
			_end_current(true)
		else:
			_start_next()
	else:
		_queue.push_back(conversation)
		if current == null:
			_start_next()
	return conversation


## Shows the rest of a line that's still typing, or moves on to the next.
func advance() -> void:
	if current == null:
		return
	if not is_line_complete():
		_shown = get_text().length()
	else:
		_next_line()


## Ends the current conversation. Anything queued after it still plays.
func skip() -> void:
	if current:
		_end_current(true)


## Drops everything without notifying anyone (scene changes and tests).
func reset() -> void:
	current = null
	_queue.clear()
	_shown = 0.0
	_hold = 0.0
	auto_advance = true


func is_busy() -> bool:
	return current != null


## Whether a conversation with this id is showing or queued.
func is_playing(id: StringName) -> bool:
	if current and current.id == id:
		return true
	return _queue.any(func(c: Conversation) -> bool: return c.id == id)


func get_line() -> Dictionary:
	return current.current_line() if current else {}


func get_text() -> String:
	return get_line().get("text", "")


func get_speaker() -> StringName:
	return get_line().get("speaker", &"")


## How many characters of the current line are visible.
func get_visible_count() -> int:
	return int(_shown)


func is_line_complete() -> bool:
	return _shown >= get_text().length()


## How long auto-advance keeps the current line up once it's shown.
func get_auto_time() -> float:
	return auto_delay + auto_delay_per_char * get_text().length() + get_line().get("hold", 0.0)


## Steps typing and auto-advance. Runs every frame; tests may call it too.
func update(delta: float) -> void:
	if current == null:
		return
	var length := get_text().length()
	if _shown < length:
		_shown = minf(length, _shown + chars_per_second * delta)
		return
	_hold += delta
	if auto_advance and _hold >= get_auto_time():
		_next_line()


func _start_next() -> void:
	if current or _queue.is_empty():
		return
	current = _queue.pop_front()
	conversation_started.emit(current)
	# A listener may have skipped or replaced it already.
	if current:
		_start_line()


func _start_line() -> void:
	_shown = 0.0
	_hold = 0.0
	line_started.emit(get_line())


func _next_line() -> void:
	current.index += 1
	if current.index >= current.lines.size():
		_end_current(false)
	else:
		_start_line()


## Clears `current` before telling anyone, so listeners that queue or
## interrupt from inside the signal see a consistent state.
func _end_current(early: bool) -> void:
	var ended := current
	current = null
	_shown = 0.0
	_hold = 0.0
	ended._finish(early)
	conversation_finished.emit(ended)
	if current == null:
		_start_next()
