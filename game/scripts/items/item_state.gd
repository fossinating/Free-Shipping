class_name ItemState
extends RefCounted
## One particular item: what it is, plus its wear. The same state moves
## between a pickup in the world, the inventory, and the dock stash.

var id: StringName
## Swings left before the tool breaks; -1 for items that don't wear.
var durability := -1
## Charges left on a disguise; -1 for unlimited.
var uses := -1


func _init(item_id: StringName) -> void:
	id = item_id
	var def := ItemCatalog.get_def(id)
	durability = def.get("durability", -1)
	uses = def.get("uses", -1)


func get_def() -> Dictionary:
	return ItemCatalog.get_def(id)


func get_name() -> String:
	return ItemCatalog.name_of(id)


func get_kind() -> ItemCatalog.Kind:
	return ItemCatalog.get_kind(id)


func is_contraband() -> bool:
	return ItemCatalog.is_contraband(id)


func get_max_durability() -> int:
	return get_def().get("durability", -1)


func wears() -> bool:
	return get_max_durability() > 0


func is_broken() -> bool:
	return wears() and durability <= 0


func needs_repair() -> bool:
	return wears() and durability < get_max_durability()


## Uses up one point of durability. Returns true if that broke it.
func wear(amount := 1) -> bool:
	if not wears() or is_broken():
		return false
	durability = maxi(0, durability - amount)
	return durability == 0


func repair() -> void:
	if wears():
		durability = get_max_durability()


## "Box cutter 4/6", "Scanner spoofer ×2", "Box cutter (broken)"
func get_label() -> String:
	if is_broken():
		return "%s (broken)" % get_name()
	if wears():
		return "%s %d/%d" % [get_name(), durability, get_max_durability()]
	if uses >= 0:
		return "%s ×%d" % [get_name(), uses]
	return get_name()


## This item as plain data for a save file.
func to_data() -> Dictionary:
	return {"id": String(id), "durability": durability, "uses": uses}


## An item from `to_data()`, or null if its id no longer exists.
static func from_data(data: Dictionary) -> ItemState:
	var item_id := StringName(data.get("id", ""))
	if ItemCatalog.get_def(item_id).is_empty():
		return null
	var state := ItemState.new(item_id)
	state.durability = int(data.get("durability", state.durability))
	state.uses = int(data.get("uses", state.uses))
	return state


static func list_to_data(items: Array[ItemState]) -> Array:
	return items.map(func(state: ItemState) -> Dictionary: return state.to_data())


static func list_from_data(list: Array) -> Array[ItemState]:
	var items: Array[ItemState] = []
	for data: Dictionary in list:
		var state := from_data(data)
		if state:
			items.append(state)
	return items
