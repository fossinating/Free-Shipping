class_name Zone
extends Area3D
## A named part of the warehouse. Zones decide what counts as normal
## there: whether your badge allows you in, and whether resizing is part
## of the work (like in storage aisles).

@export var zone_name := "Fulfillment"
## Badge clearance needed to be here without raising suspicion.
@export var required_clearance := 0
## Growing and shrinking is normal here.
@export var allow_resize := false


func _ready() -> void:
	add_to_group(&"zones")
	monitorable = false


## Zones the body is standing in.
static func zones_at(body: Node3D) -> Array[Zone]:
	var found: Array[Zone] = []
	for zone: Zone in body.get_tree().get_nodes_in_group(&"zones"):
		if zone.overlaps_body(body):
			found.append(zone)
	return found
