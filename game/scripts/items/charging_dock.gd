class_name ChargingDock
extends Node3D
## Your charging dock: where you stash items, repair tools and craft.
## The stash has no size limit. Security only searches it once suspicion
## stays high (see Security.search_docks); what it finds goes to the
## evidence locker.

signal changed

## Robots within this distance of the dock can use it.
@export var reach := 2.2
## Suspicion at or above which security searches this dock.
@export var search_suspicion := 80.0

var stash: Array[ItemState] = []


func _ready() -> void:
	add_to_group(&"docks")


## The dock `robot` is close enough to use, or null.
static func find_near(robot: RobotBody) -> ChargingDock:
	for dock: ChargingDock in robot.get_tree().get_nodes_in_group(&"docks"):
		if dock.is_in_reach(robot):
			return dock
	return null


func is_in_reach(robot: RobotBody) -> bool:
	var offset := robot.global_position - global_position
	return Vector2(offset.x, offset.z).length() <= reach and absf(offset.y) < 2.0


## Moves an item from the inventory into the stash.
func put(inventory: Inventory, state: ItemState) -> bool:
	if not inventory.remove(state):
		return false
	stash.append(state)
	changed.emit()
	return true


## Moves an item from the stash into the inventory, if there's room.
func take(inventory: Inventory, state: ItemState) -> bool:
	if not stash.has(state) or not inventory.add(state):
		return false
	stash.erase(state)
	changed.emit()
	return true


func count(id: StringName, inventory: Inventory = null) -> int:
	var total := inventory.count(id) if inventory else 0
	for state in stash:
		if state.id == id:
			total += 1
	return total


## Restores a tool to full durability using one repair material (tape),
## taken from the stash before the inventory.
func repair(state: ItemState, inventory: Inventory) -> bool:
	if state == null or not state.needs_repair():
		return false
	var material := _find_repair_material(inventory, state)
	if material == null:
		return false
	_consume(material, inventory)
	state.repair()
	inventory.changed.emit()
	changed.emit()
	return true


## Whether the dock has every ingredient for a recipe (an index into
## ItemCatalog.RECIPES), counting the stash and the inventory.
func can_craft(recipe: int, inventory: Inventory) -> bool:
	return not _gather(recipe, inventory).is_empty()


## Crafts a known recipe. The result goes into the inventory if there's
## room, otherwise the stash. Returns it, or null if it can't be made.
func craft(recipe: int, inventory: Inventory) -> ItemState:
	if not GameState.knows_recipe(recipe):
		return null
	var ingredients := _gather(recipe, inventory)
	if ingredients.is_empty():
		return null
	for state in ingredients:
		_consume(state, inventory)
	var result := ItemState.new(ItemCatalog.RECIPES[recipe].result)
	if not inventory.add(result):
		stash.append(result)
		GameState.note_held(result.id)
	changed.emit()
	return result


## Guards would search this dock right now.
func is_searchable() -> bool:
	return Suspicion.value >= search_suspicion


## Empties the stash and returns what was in it.
func confiscate() -> Array[ItemState]:
	var taken: Array[ItemState] = stash.duplicate()
	stash.clear()
	changed.emit()
	return taken


## One distinct item per recipe input, or [] if something is missing.
func _gather(recipe: int, inventory: Inventory) -> Array[ItemState]:
	var pool: Array[ItemState] = stash.duplicate()
	pool.append_array(inventory.get_items())
	var picked: Array[ItemState] = []
	for input: StringName in ItemCatalog.RECIPES[recipe].inputs:
		var found: ItemState = null
		for state in pool:
			if state.id == input:
				found = state
				break
		if found == null:
			return []
		pool.erase(found)
		picked.append(found)
	return picked


func _find_repair_material(inventory: Inventory, exclude: ItemState) -> ItemState:
	var pool: Array[ItemState] = stash.duplicate()
	pool.append_array(inventory.get_items())
	for state in pool:
		if state != exclude and state.get_def().get("repair", false):
			return state
	return null


func _consume(state: ItemState, inventory: Inventory) -> void:
	if stash.has(state):
		stash.erase(state)
	else:
		inventory.remove(state)
