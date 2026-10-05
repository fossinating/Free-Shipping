class_name ErrorCounter
extends Logger
## Collects engine and script errors so the runner can fail a test that
## crashed partway instead of counting it as passed.

var _mutex := Mutex.new()
var _errors: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var message := rationale if rationale != "" else code
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [message, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


## Returns the errors since the last call and clears them.
func take() -> PackedStringArray:
	_mutex.lock()
	var errors := _errors
	_errors = []
	_mutex.unlock()
	return errors
