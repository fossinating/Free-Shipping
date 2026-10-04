class_name PackageSpawner
extends Marker3D
## Keeps a small pile of packages stocked at this spot, like an incoming
## conveyor that never runs dry.

const PACKAGE_SCENE := preload("res://scenes/work/package.tscn")

## How many packages to keep within `radius` of this spot.
@export var stock := 3
@export var radius := 2.0
@export var interval := 1.0
## Destinations to cycle through. Empty gives untagged packages.
@export var destinations: Array[StringName] = []

var _timer := 0.0
var _spawned := 0


func _ready() -> void:
	# Start with a row along the spawner's X axis.
	for i in stock:
		_spawn(global_basis.x * (i - (stock - 1) / 2.0) * 0.9 + Vector3.UP * 0.3)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval
	if _count_nearby() < stock:
		_spawn(global_basis.x * randf_range(-0.5, 0.5) + Vector3.UP * 0.8)


func _count_nearby() -> int:
	var count := 0
	for package: Package in get_tree().get_nodes_in_group(&"packages"):
		if not package.is_held() \
				and package.global_position.distance_to(global_position) < radius:
			count += 1
	return count


func _spawn(offset: Vector3) -> void:
	var package: Package = PACKAGE_SCENE.instantiate()
	if not destinations.is_empty():
		package.destination = destinations[_spawned % destinations.size()]
	package.source = self
	_spawned += 1
	var parent := get_parent()
	var spot := global_position + offset
	package.position = (parent as Node3D).to_local(spot) if parent is Node3D else spot
	get_parent().add_child.call_deferred(package)
