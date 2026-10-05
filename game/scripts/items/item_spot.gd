class_name ItemSpot
extends Marker3D
## A spot where something from a zone's item pool turns up (see
## ItemCatalog.POOLS). What it is changes from game to game.

@export var pool: StringName = &"receiving"

## The pickup that turned up here, once it has.
var item: Item


func _ready() -> void:
	_spawn.call_deferred()


func _spawn() -> void:
	var id := ItemCatalog.pick_from_pool(pool)
	if id == &"":
		push_warning("ItemSpot %s: unknown pool %s" % [name, pool])
		return
	item = Item.spawn(ItemState.new(id), get_parent(), global_position)
