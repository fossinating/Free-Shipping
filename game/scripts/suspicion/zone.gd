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


## Whether a point is inside this zone's box shapes.
func contains_point(point: Vector3) -> bool:
	for child in get_children():
		var shape_node := child as CollisionShape3D
		if shape_node and shape_node.shape is BoxShape3D:
			var local := shape_node.global_transform.affine_inverse() * point
			var half := (shape_node.shape as BoxShape3D).size / 2.0
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				return true
	return false


func get_volume() -> float:
	var volume := 0.0
	for child in get_children():
		var shape_node := child as CollisionShape3D
		if shape_node and shape_node.shape is BoxShape3D:
			var size := (shape_node.shape as BoxShape3D).size
			volume += size.x * size.y * size.z
	return volume
