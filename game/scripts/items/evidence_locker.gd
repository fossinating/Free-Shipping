class_name EvidenceLocker
extends Node3D
## Where confiscated items end up: everything security took when you were
## wiped or your dock was searched (GameState.evidence). Security's own
## locker needs level 4, so for now each zone has a smaller holding locker
## you can sneak into to take your things back. Every locker opens onto the
## same evidence, wherever it was confiscated.

signal retrieved(items: Array[ItemState])

## Robots within this distance of the locker can open it.
@export var reach := 1.8

@onready var _sign: Label3D = get_node_or_null(^"Sign")


func _ready() -> void:
	add_to_group(&"evidence_lockers")
	GameState.evidence_changed.connect(_update_sign)
	_update_sign()


## The locker `robot` is close enough to open, or null.
static func find_near(robot: RobotBody) -> EvidenceLocker:
	for locker: EvidenceLocker in robot.get_tree().get_nodes_in_group(&"evidence_lockers"):
		if locker.is_in_reach(robot):
			return locker
	return null


func is_in_reach(robot: RobotBody) -> bool:
	var offset := robot.global_position - global_position
	return Vector2(offset.x, offset.z).length() <= reach and absf(offset.y) < 2.0


## How many confiscated items are waiting.
func get_count() -> int:
	return GameState.evidence.size()


## Takes back as many confiscated items as the inventory has room for.
## Returns what was taken.
func retrieve(inventory: Inventory) -> Array[ItemState]:
	var taken: Array[ItemState] = []
	for state in GameState.evidence.duplicate():
		if not inventory.add(state):
			break
		taken.append(state)
	if not taken.is_empty():
		GameState.release_evidence(taken)
		retrieved.emit(taken)
	return taken


func _update_sign() -> void:
	if _sign:
		var count := get_count()
		_sign.text = "HOLDING LOCKER\n%s" % ("empty" if count == 0 else "%d item%s" % [count,
			"" if count == 1 else "s"])
