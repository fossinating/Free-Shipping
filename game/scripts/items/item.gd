class_name Item
extends Package
## An item lying around the warehouse. Robots grab, carry and throw it like
## a package, and the player can stow it in their inventory. The item's
## identity and wear live in `state`, which moves with it into the
## inventory and the dock stash.

const SCENE_PATH := "res://scenes/items/item.tscn"

## What this pickup is (a key of ItemCatalog.ITEMS). Ignored if `state` is
## set before the item enters the tree.
@export var item_id: StringName = &"tape"

var state: ItemState

@onready var _tag: Label3D = $Tag


## A new pickup for `item_state` at a world position, added under `parent`.
static func spawn(item_state: ItemState, parent: Node, at: Vector3) -> Item:
	var item: Item = load(SCENE_PATH).instantiate()
	item.state = item_state
	item.item_id = item_state.id
	parent.add_child(item)
	item.global_position = at
	return item


func _ready() -> void:
	if state == null:
		state = ItemState.new(item_id)
	var def := state.get_def()
	size = def.get("size", Vector3(0.3, 0.2, 0.3))
	contraband = state.is_contraband()
	super._ready()
	add_to_group(&"items")
	_tag.position.y = size.y / 2.0 + 0.25
	_tag.text = state.get_name()


## Items are never stock: carrying one doesn't look like work.
func is_stock() -> bool:
	return false


func _update_label() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = state.get_def().get("color", Color.WHITE) if state else Color.WHITE
	_mesh.material_override = material
	_label.hide()


## Tools hit with their own damage, and a hit wears them like a swing.
func _hurt(robot: RobotBody, speed: float) -> void:
	if state.get_kind() == ItemCatalog.Kind.TOOL and not state.is_broken():
		state.wear()
		Combat.hit(thrown_by, robot, linear_velocity,
			state.get_def().get("damage", 6.0), state.get_def().get("stun", 1.0))
	else:
		super._hurt(robot, speed)
