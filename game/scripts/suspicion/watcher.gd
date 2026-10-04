class_name Watcher
extends Node3D
## Something that can see the player: a camera's lens or a robot's eyes.
## Looks along -Z. While it can see the player committing an offense it
## raises suspicion, either steadily or as one-off reports.

## Started or stopped seeing the player do something suspicious.
signal alarm_changed(alarmed: bool)
## Made a one-off report (report_amount > 0).
signal reported(offenses: Dictionary)

@export var fov_degrees := 70.0
@export var view_range := 14.0
## Suspicion per second for each point of offense severity.
@export var sensitivity := 4.0
## Offenses less severe than this go unnoticed.
@export var min_severity := 0.0
## If above zero, report this much once instead of raising suspicion
## steadily, then wait report_cooldown seconds.
@export var report_amount := 0.0
@export var report_cooldown := 8.0

var target: RobotBody
var sees_target := false
var alarmed := false
var current_offenses := {}

var _cooldown := 0.0


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as RobotBody
		if target == null:
			return
	_cooldown = maxf(0.0, _cooldown - delta)
	sees_target = can_see(target)
	current_offenses = {}
	if sees_target:
		var offenses := Offenses.evaluate(target)
		for offense in offenses:
			if offenses[offense] >= min_severity:
				current_offenses[offense] = offenses[offense]
	var now_alarmed := not current_offenses.is_empty()
	if now_alarmed != alarmed:
		alarmed = now_alarmed
		alarm_changed.emit(alarmed)
	Suspicion.report(self, sees_target, alarmed)
	if not alarmed:
		return
	var reason := Offenses.describe(current_offenses)
	if report_amount > 0.0:
		if _cooldown <= 0.0:
			_cooldown = report_cooldown
			Suspicion.add(report_amount, reason)
			reported.emit(current_offenses)
	else:
		var severity := 0.0
		for offense in current_offenses:
			severity += current_offenses[offense]
		Suspicion.add(severity * sensitivity * delta, reason)


## Whether the robot's core or treads are in view and not blocked.
func can_see(robot: RobotBody) -> bool:
	var eye := global_position
	var forward := -global_basis.z
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var owner_body := _owning_body()
	if owner_body:
		exclude.append(owner_body.get_rid())
	if robot.held:
		exclude.append(robot.held.get_rid())
	for point: Vector3 in [robot.get_core_position(), robot.global_position + Vector3.UP * 0.3]:
		var offset := point - eye
		if offset.length() > view_range:
			continue
		if forward.angle_to(offset) > deg_to_rad(fov_degrees) / 2.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, point, 1, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider == robot:
			return true
	return false


func _owning_body() -> CollisionObject3D:
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			return node
		node = node.get_parent()
	return null
