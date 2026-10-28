class_name Settings
## Player settings that outlast a playthrough, kept apart from the save so
## starting over doesn't reset them.

## Tests point this somewhere else.
static var path := "user://settings.cfg"
const DEFAULT_MOUSE_SENSITIVITY := 0.0025

static var mouse_sensitivity := DEFAULT_MOUSE_SENSITIVITY
static var _loaded := false


## Reads the settings file once; later calls do nothing.
static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(path) == OK:
		mouse_sensitivity = file.get_value("input", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	if file.save(path) != OK:
		push_warning("Settings: can't write %s" % path)
