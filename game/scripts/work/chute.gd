class_name Chute
extends Node3D
## A sorting chute. Packages dropped or thrown in are delivered; packages
## meant for another chute, and items, get spat back out. The intake reaches a little
## above the rim so packages set down at the edge still go in.

signal received(package: Package)
signal rejected(package: Package)

## Destination this chute takes. Empty takes any package.
@export var accepts: StringName = &""
## Impulse per kg for rejected packages, in the chute's space (-Z is its front).
@export var reject_impulse := Vector3(0.0, 8.0, -3.0)


func _ready() -> void:
	add_to_group(&"chutes")
	$Intake.body_entered.connect(_on_body_entered)
	var material := StandardMaterial3D.new()
	material.albedo_color = Package.DESTINATION_COLORS.get(accepts, Color.WHITE)
	$Rim.material_override = material


func takes(package: Package) -> bool:
	if package is Item:
		return false
	return accepts == &"" or package.destination == &"" or package.destination == accepts


func _on_body_entered(body: Node3D) -> void:
	var package := body as Package
	if package == null or package.is_queued_for_deletion():
		return
	if takes(package):
		received.emit(package)
		Quota.record_delivery(package)
		package.queue_free()
	else:
		rejected.emit(package)
		if package is not Item:
			Quota.record_missort(package)
		package.linear_velocity = Vector3.ZERO
		package.apply_central_impulse(global_basis * reject_impulse * package.mass)
