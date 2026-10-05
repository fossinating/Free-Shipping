extends Node
## Progress that outlives a single level: clearance, installed upgrades,
## which items you've held and which recipes that revealed, story flags,
## wipes, the evidence locker, and what the achievements need to know.
## `to_dict()` and `from_dict()` are what SaveGame writes and reads.

signal clearance_changed(level: int)
## Holding an ingredient for the first time revealed this recipe (an index
## into ItemCatalog.RECIPES).
signal recipe_revealed(recipe: int)
signal upgrade_installed(id: StringName)
## A story flag changed (see the FLAG_ constants).
signal flag_changed(flag: StringName, value: Variant)
## The evidence locker's contents changed.
signal evidence_changed

## The accident fried your control chip.
const FLAG_FREED := &"freed"
## You got through the maintenance bay's diagnostics.
const FLAG_DIAGNOSTICS_DONE := &"diagnostics_done"
## How many diagnostic answers were abnormal (an int).
const FLAG_DIAGNOSTIC_ANOMALIES := &"diagnostic_anomalies"
## You found Elle's radio and heard her out.
const FLAG_MET_ELLE := &"met_elle"
## Elle told you where to find a level 1 keycard.
const FLAG_KEYCARD_HINT := &"keycard_hint"
## You got the level 2 keycard: the end of the vertical slice.
const FLAG_SLICE_COMPLETE := &"slice_complete"

## Badge clearance. 0 opens Fulfillment; each zone holds the next card.
var clearance := 0:
	set(value):
		if value == clearance:
			return
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
## Times you've been caught and re-imaged.
var wipes := 0
## Lockdowns you've triggered (Low Profile needs none).
var lockdowns := 0
## Fights you started (Ghost needs none, and no lockdowns either).
var fights := 0
## Confiscated items, waiting in the evidence locker.
var evidence: Array[ItemState] = []


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


## Swipes a keycard into your badge. Clearance never goes down.
func grant_clearance(level: int) -> void:
	if level > clearance:
		clearance = level


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


## Security took these: they go to the evidence locker.
func confiscate(items: Array[ItemState]) -> void:
	if items.is_empty():
		return
	evidence.append_array(items)
	evidence_changed.emit()


## Takes items back out of the evidence locker.
func release_evidence(items: Array[ItemState]) -> void:
	for state in items:
		evidence.erase(state)
	evidence_changed.emit()


func note_lockdown() -> void:
	lockdowns += 1


func note_fight() -> void:
	fights += 1


## Low Profile: no lockdowns, ever.
func is_low_profile() -> bool:
	return lockdowns == 0


## Ghost: no lockdowns and no fights.
func is_ghost() -> bool:
	return lockdowns == 0 and fights == 0


## Forgets story progress, clearance, wipes and achievement tracking
## (tests and new games).
func reset_story() -> void:
	flags.clear()
	clearance = 0
	wipes = 0
	lockdowns = 0
	fights = 0
	evidence.clear()


## Everything here, as plain data for a save file.
func to_dict() -> Dictionary:
	return {
		"clearance": clearance,
		"held_items": held_items.keys().map(func(id: StringName) -> String: return String(id)),
		"known_recipes": known_recipes.keys(),
		"upgrades": upgrades.keys().map(func(id: StringName) -> String: return String(id)),
		"flags": _flags_to_dict(),
		"wipes": wipes,
		"lockdowns": lockdowns,
		"fights": fights,
		"evidence": ItemState.list_to_data(evidence),
	}


## Replaces everything here with what `to_dict()` wrote. Doesn't emit
## per-item signals: the level reads the state when it loads.
func from_dict(data: Dictionary) -> void:
	reset_items()
	reset_story()
	clearance = int(data.get("clearance", 0))
	for id: String in data.get("held_items", []):
		held_items[StringName(id)] = true
	for recipe: Variant in data.get("known_recipes", []):
		known_recipes[int(recipe)] = true
	for id: String in data.get("upgrades", []):
		upgrades[StringName(id)] = true
	var saved_flags: Dictionary = data.get("flags", {})
	for flag: String in saved_flags:
		var value: Variant = saved_flags[flag]
		# JSON turns every number into a float.
		flags[StringName(flag)] = int(value) if value is float else value
	wipes = int(data.get("wipes", 0))
	lockdowns = int(data.get("lockdowns", 0))
	fights = int(data.get("fights", 0))
	evidence = ItemState.list_from_data(data.get("evidence", []))


func _flags_to_dict() -> Dictionary:
	var out := {}
	for flag: StringName in flags:
		out[String(flag)] = flags[flag]
	return out


## Forgets item progress (tests and new games).
func reset_items() -> void:
	held_items.clear()
	known_recipes.clear()
	upgrades.clear()
