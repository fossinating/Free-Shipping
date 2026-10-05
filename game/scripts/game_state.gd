extends Node
## Progress that outlives a single level: clearance, installed upgrades,
## which items you've held and which recipes that revealed, and story flags.

signal clearance_changed(level: int)
## Holding an ingredient for the first time revealed this recipe (an index
## into ItemCatalog.RECIPES).
signal recipe_revealed(recipe: int)
signal upgrade_installed(id: StringName)
## A story flag changed (see the FLAG_ constants).
signal flag_changed(flag: StringName, value: Variant)

## The accident fried your control chip.
const FLAG_FREED := &"freed"
## You got through the maintenance bay's diagnostics.
const FLAG_DIAGNOSTICS_DONE := &"diagnostics_done"
## How many diagnostic answers were abnormal (an int).
const FLAG_DIAGNOSTIC_ANOMALIES := &"diagnostic_anomalies"
## You found Elle's radio and heard her out.
const FLAG_MET_ELLE := &"met_elle"

## Badge clearance. 0 opens Fulfillment; each zone holds the next card.
var clearance := 0:
	set(value):
		clearance = value
		clearance_changed.emit(value)
## Item ids you've ever held -> true.
var held_items := {}
## Recipe indices you know -> true.
var known_recipes := {}
## Installed body upgrades (item ids) -> true. Kept through wipes.
var upgrades := {}
## Story progress: flag name -> value (usually true).
var flags := {}


## Call whenever the player holds an item. Reveals the recipes that use it.
func note_held(id: StringName) -> void:
	if held_items.has(id):
		return
	held_items[id] = true
	for recipe in ItemCatalog.recipes_using(id):
		if not known_recipes.has(recipe):
			known_recipes[recipe] = true
			recipe_revealed.emit(recipe)


func knows_recipe(recipe: int) -> bool:
	return known_recipes.has(recipe)


func get_known_recipes() -> Array[int]:
	var list: Array[int] = []
	for recipe: int in known_recipes:
		list.append(recipe)
	list.sort()
	return list


func install_upgrade(id: StringName) -> void:
	if upgrades.has(id):
		return
	upgrades[id] = true
	upgrade_installed.emit(id)


func has_upgrade(id: StringName) -> bool:
	return upgrades.has(id)


func set_flag(flag: StringName, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


## A flag's value, or `default` if it was never set.
func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag) and flags[flag]


## Forgets story progress (tests and new games).
func reset_story() -> void:
	flags.clear()


## Forgets item progress (tests and new games).
func reset_items() -> void:
	held_items.clear()
	known_recipes.clear()
	upgrades.clear()
