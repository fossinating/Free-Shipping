class_name DockPanel
extends PanelContainer
## The charging dock's menu: what you carry, what's stashed, and the
## recipes you know. Built in code; the HUD opens it while the player's
## controller has a dock open.

var dock: ChargingDock
var inventory: Inventory

var _columns: HBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(900, 380)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.1, 0.92)
	style.border_color = Color(0.3, 0.9, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	var outer := VBoxContainer.new()
	add_child(outer)
	var title := Label.new()
	title.text = "YOUR DOCK   (C or Esc to close)"
	title.add_theme_font_size_override("font_size", 22)
	outer.add_child(title)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 24)
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_columns)
	hide()


func open(new_dock: ChargingDock, new_inventory: Inventory) -> void:
	close()
	dock = new_dock
	inventory = new_inventory
	dock.changed.connect(_rebuild)
	inventory.changed.connect(_rebuild)
	_rebuild()
	show()


func close() -> void:
	if dock and dock.changed.is_connected(_rebuild):
		dock.changed.disconnect(_rebuild)
	if inventory and inventory.changed.is_connected(_rebuild):
		inventory.changed.disconnect(_rebuild)
	dock = null
	inventory = null
	hide()


func _rebuild() -> void:
	for child in _columns.get_children():
		child.queue_free()
	var carrying := _column("CARRYING  (%d/%d)" % [inventory.get_items().size(), Inventory.SLOT_COUNT])
	for state in inventory.get_items():
		var row := _row(carrying, state.get_label())
		_button(row, "Stash", dock.put.bind(inventory, state))
		_repair_button(row, state)
	var stash := _column("STASH")
	if dock.stash.is_empty():
		_row(stash, "(empty)")
	for state in dock.stash:
		var row := _row(stash, state.get_label())
		_button(row, "Take", dock.take.bind(inventory, state), not inventory.is_full())
		_repair_button(row, state)
	var recipes := _column("RECIPES")
	var known := GameState.get_known_recipes()
	if known.is_empty():
		_row(recipes, "Hold an item to learn what it makes")
	for recipe in known:
		var row := _row(recipes, ItemCatalog.describe_recipe(recipe))
		_button(row, "Craft", dock.craft.bind(recipe, inventory), dock.can_craft(recipe, inventory))


func _repair_button(row: Control, state: ItemState) -> void:
	if state.needs_repair():
		_button(row, "Repair (tape)", dock.repair.bind(state, inventory),
			dock.count(&"tape", inventory) > 0)


func _column(heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(column)
	var label := Label.new()
	label.text = heading
	label.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	column.add_child(label)
	return column


func _row(column: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	column.add_child(row)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120
	row.add_child(label)
	return row


func _button(row: HBoxContainer, text: String, action: Callable, enabled := true) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: action.call())
	row.add_child(button)
