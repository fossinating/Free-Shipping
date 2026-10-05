class_name Conversation
extends RefCounted
## One queued run of dialogue lines. `Dialogue.play()` returns it; await
## `wait()` to continue once it's over, however it ended (played out,
## skipped or interrupted). Unlike awaiting a signal, `wait()` returns at
## once if the conversation already finished, so callers can't hang.

signal finished

## The conversation's id in DialogueLines, or &"" for ad hoc lines.
var id: StringName
## Each line is {"speaker": StringName, "text": String}.
var lines: Array[Dictionary] = []
## Index of the line showing now (or next, while queued).
var index := 0
var done := false
## Ended early: skipped by the player or cut off by an interruption.
var cut_short := false


func _init(conversation_id: StringName, conversation_lines: Array) -> void:
	id = conversation_id
	for line: Dictionary in conversation_lines:
		lines.append(line)


func current_line() -> Dictionary:
	return lines[index] if index < lines.size() else {}


func wait() -> void:
	if not done:
		await finished


func _finish(early: bool) -> void:
	if done:
		return
	done = true
	cut_short = early
	finished.emit()
