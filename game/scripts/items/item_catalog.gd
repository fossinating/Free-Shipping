class_name ItemCatalog
## Every item and crafting recipe in the game, as plain tables.
##
## Items come in kinds: upgrades are permanent body parts, tools are loud
## and wear down, disguises are quiet and help keep up the act, and
## materials are common junk that goes into recipes and repairs.

enum Kind { MATERIAL, TOOL, DISGUISE, UPGRADE }

const KIND_NAMES := {
	Kind.MATERIAL: "Material",
	Kind.TOOL: "Tool",
	Kind.DISGUISE: "Disguise",
	Kind.UPGRADE: "Upgrade",
}

## id -> definition. Keys besides name and kind are optional:
## - color: how the pickup looks.
## - size: pickup box size.
## - contraband: suspicious to be seen holding.
## - durability: tools wear by one per swing or hit and break at 0.
## - damage: how hard a tool hits (knockback speed, m/s).
## - stun: seconds a hit leaves the target unable to move.
## - uses: disguises with charges run out after this many uses.
## - clearance_bonus: passive badge clearance while equipped.
## - key_part: the one fixed-location part an upgrade recipe needs.
## - repair: this material repairs tools at the dock.
const ITEMS := {
	&"tape": {
		"name": "Tape", "kind": Kind.MATERIAL, "repair": true,
		"color": Color(0.85, 0.75, 0.55), "size": Vector3(0.3, 0.12, 0.3),
		"blurb": "Repairs tools at your dock. Holds anything together.",
	},
	&"magnet": {
		"name": "Magnet", "kind": Kind.MATERIAL,
		"color": Color(0.8, 0.2, 0.2), "size": Vector3(0.25, 0.2, 0.25),
		"blurb": "A strong magnet from Electronics.",
	},
	&"scrap_circuit": {
		"name": "Scrap circuit", "kind": Kind.MATERIAL,
		"color": Color(0.2, 0.6, 0.3), "size": Vector3(0.35, 0.06, 0.25),
		"blurb": "A board pulled from a broken scanner.",
	},
	&"box_cutter": {
		"name": "Box cutter", "kind": Kind.TOOL, "contraband": true,
		"durability": 6, "damage": 7.0, "stun": 1.2,
		"color": Color(0.95, 0.8, 0.1), "size": Vector3(0.1, 0.08, 0.4),
		"blurb": "Loud and sharp. Wears down with every swing.",
	},
	&"taped_blade": {
		"name": "Taped blade", "kind": Kind.TOOL, "contraband": true,
		"durability": 10, "damage": 9.0, "stun": 1.6,
		"color": Color(0.9, 0.85, 0.6), "size": Vector3(0.12, 0.1, 0.5),
		"blurb": "A box cutter taped to a slat. Longer, sturdier.",
	},
	&"magnetic_grabber_blade": {
		"name": "Magnetic grabber blade", "kind": Kind.TOOL, "contraband": true,
		"durability": 14, "damage": 12.0, "stun": 2.2,
		"color": Color(0.7, 0.3, 0.8), "size": Vector3(0.15, 0.12, 0.6),
		"blurb": "Sticks to whatever it hits.",
	},
	&"scanner_spoofer": {
		"name": "Scanner spoofer", "kind": Kind.DISGUISE, "uses": 3,
		"color": Color(0.2, 0.8, 0.9), "size": Vector3(0.25, 0.1, 0.18),
		"blurb": "Logs a delivery you never made. Quiet.",
	},
	&"fake_id": {
		"name": "Fake ID tag", "kind": Kind.DISGUISE, "clearance_bonus": 1,
		"color": Color(0.95, 0.95, 0.95), "size": Vector3(0.2, 0.03, 0.14),
		"blurb": "While equipped, scanners read one clearance level higher.",
	},
	&"electromagnet_coil": {
		"name": "Electromagnet coil", "kind": Kind.MATERIAL, "key_part": true,
		"color": Color(0.85, 0.5, 0.15), "size": Vector3(0.3, 0.3, 0.3),
		"blurb": "Key part. Only one in the warehouse.",
	},
	&"magnetic_hands": {
		"name": "Magnetic hands", "kind": Kind.UPGRADE,
		"color": Color(0.4, 0.4, 0.9), "size": Vector3(0.35, 0.2, 0.35),
		"blurb": "Install to climb metal shelving.",
	},
}

## Each recipe takes 2 items, 3 at most. Results can be ingredients of
## other recipes, so they form a tree. A recipe is revealed once you've
## held any of its ingredients.
const RECIPES := [
	{"result": &"taped_blade", "inputs": [&"tape", &"box_cutter"]},
	{"result": &"magnetic_grabber_blade", "inputs": [&"taped_blade", &"magnet"]},
	{"result": &"scanner_spoofer", "inputs": [&"scrap_circuit", &"magnet", &"tape"]},
	{"result": &"magnetic_hands", "inputs": [&"magnet", &"electromagnet_coil"]},
]

const MAX_INPUTS := 3


static func has(id: StringName) -> bool:
	return ITEMS.has(id)


static func get_def(id: StringName) -> Dictionary:
	return ITEMS.get(id, {})


static func name_of(id: StringName) -> String:
	return get_def(id).get("name", str(id))


static func get_kind(id: StringName) -> Kind:
	return get_def(id).get("kind", Kind.MATERIAL)


static func is_contraband(id: StringName) -> bool:
	return get_def(id).get("contraband", false)


static func is_key_part(id: StringName) -> bool:
	return get_def(id).get("key_part", false)


## Recipes that use this item, as indices into RECIPES.
static func recipes_using(id: StringName) -> Array[int]:
	var found: Array[int] = []
	for i in RECIPES.size():
		if id in RECIPES[i].inputs:
			found.append(i)
	return found


## "Tape + Box cutter → Taped blade"
static func describe_recipe(index: int) -> String:
	var recipe: Dictionary = RECIPES[index]
	var names: PackedStringArray = []
	for input: StringName in recipe.inputs:
		names.append(name_of(input))
	return "%s → %s" % [" + ".join(names), name_of(recipe.result)]
