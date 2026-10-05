class_name SaveGame
## Saving and loading. One save slot, as JSON in user://.
##
## A save holds GameState (clearance, flags, recipes, upgrades, wipes, the
## evidence locker and achievement tracking), plus the level it was made
## in: where the player stood, their inventory, their dock's stash and the
## items lying around. You save by walking into the maintenance bay.
##
## Loading is two steps, because the level has to exist before it can be
## restored: `load_game()` restores GameState and changes to the saved
## level, and that level calls `take_pending()` and `apply_level()` in its
## `_ready()`.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"

## Where the save lives (tests point this somewhere else).
static var path := DEFAULT_PATH
## A loaded save waiting for its level to pick it up.
static var _pending: Dictionary = {}


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Everything worth saving about `level` and the game right now.
static func capture(level: Node, player: RobotBody, dock: ChargingDock) -> Dictionary:
	var inventory := Inventory.of(player)
	var slots: Array = []
	if inventory:
		for state in inventory.slots:
			slots.append(state.to_data() if state else null)
	var world_items: Array = []
	for item: Item in level.get_tree().get_nodes_in_group(&"items"):
		if not level.is_ancestor_of(item) or item.is_queued_for_deletion():
			continue
		var data := item.state.to_data()
		# Whatever is in the player's hands lands at their feet.
		var at := player.global_position + Vector3.UP * 0.5 if item.is_held() \
			else item.global_position
		data["position"] = _vec_to_data(at)
		world_items.append(data)
	return {
		"version": VERSION,
		"scene": level.scene_file_path,
		"game_state": GameState.to_dict(),
		"player": {
			"position": _vec_to_data(player.global_position),
			"yaw": player.rotation.y,
			"zone": _zone_name(player),
			"extension": player.extension,
		},
		"inventory": slots,
		"selected": inventory.selected if inventory else -1,
		"dock": ItemState.list_to_data(dock.stash) if dock else [],
		"world_items": world_items,
	}


static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveGame: can't write %s (%s)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Captures and writes the game. Returns whether it worked.
static func save(level: Node, player: RobotBody, dock: ChargingDock) -> bool:
	return write(capture(level, player, dock))


## The saved data, or {} if there's no usable save.
static func read() -> Dictionary:
	if not exists():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != VERSION:
		push_warning("SaveGame: %s is unreadable or from another version" % path)
		return {}
	return parsed


## Restores GameState from the save and changes to the saved level, which
## picks up the rest. Returns false if there's nothing to load.
static func load_game(tree: SceneTree) -> bool:
	var data := read()
	if data.is_empty() or not ResourceLoader.exists(data.get("scene", "")):
		return false
	begin_load(data)
	tree.change_scene_to_file(data.scene)
	return true


## Restores GameState from `data` and leaves the rest for the next level
## that starts.
static func begin_load(data: Dictionary) -> void:
	GameState.from_dict(data.get("game_state", {}))
	_pending = data


## The loaded save, once, for the level that's starting. {} if the level
## isn't being loaded from a save.
static func take_pending() -> Dictionary:
	var data := _pending
	_pending = {}
	return data


## Puts a level back the way the save found it. Call from the level's
## `_ready()`, before ItemSpots fill themselves (they wait a frame).
static func apply_level(data: Dictionary, level: Node, player: RobotBody,
		dock: ChargingDock) -> void:
	var saved_player: Dictionary = data.get("player", {})
	if saved_player.has("position"):
		player.global_position = _vec_from_data(saved_player.position)
		player.rotation.y = float(saved_player.get("yaw", 0.0))
		player.facing_yaw = player.rotation.y
		player.velocity = Vector3.ZERO
	var inventory := Inventory.of(player)
	if inventory:
		var slots: Array = data.get("inventory", [])
		for i in inventory.slots.size():
			var saved: Variant = slots[i] if i < slots.size() else null
			inventory.slots[i] = ItemState.from_data(saved) if saved is Dictionary else null
		inventory.selected = clampi(int(data.get("selected", -1)), -1, inventory.slots.size() - 1)
		inventory.changed.emit()
	if dock:
		dock.stash = ItemState.list_from_data(data.get("dock", []))
		dock.changed.emit()
	# The items lying around replace the level's own.
	for node in _descendants(level):
		if node is ItemSpot:
			node.disabled = true
		elif node is KeycardCarrier and GameState.clearance >= node.level:
			# Guards don't carry cards you've already got.
			node.remove_card()
	for item: Item in level.get_tree().get_nodes_in_group(&"items"):
		if level.is_ancestor_of(item):
			item.remove_from_group(&"items")
			item.remove_from_group(&"packages")
			item.queue_free()
	var parent: Node = level.get_node_or_null(^"Items")
	if parent == null:
		parent = level
	for entry: Dictionary in data.get("world_items", []):
		var state := ItemState.from_data(entry)
		if state:
			Item.spawn(state, parent, _vec_from_data(entry.get("position", [0, 1, 0])))


static func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out


## The name of the most specific zone the player is in, or "".
static func _zone_name(player: RobotBody) -> String:
	var best: Zone = null
	for zone in Zone.zones_at(player):
		if best == null or zone.get_volume() < best.get_volume():
			best = zone
	return best.zone_name if best else ""


static func _vec_to_data(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _vec_from_data(data: Variant) -> Vector3:
	if data is Array and data.size() == 3:
		return Vector3(float(data[0]), float(data[1]), float(data[2]))
	return Vector3.ZERO
