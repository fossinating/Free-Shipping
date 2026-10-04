class_name ControlProgram
extends Node
## Control mode. Runs the Shift children in order and filters what the
## robot is allowed to do so it can't step outside its assigned task.

signal shift_started(shift: Shift)
signal shift_finished(shift: Shift)
signal step_started(step: ShiftStep)
## The player tried something the task doesn't allow.
signal denied(reason: String)
## The robot walked into the accident; control mode is over.
signal accident

## Seconds of "end of shift" pause before the next shift starts.
@export var shift_break := 3.0
## How far ahead movement is checked against the route corridor.
@export var lookahead := 0.4
@export var robot: RobotBody

var active := false
var current_shift: Shift
var current_step: ShiftStep

var _shift_index := -1
var _step_index := -1
var _route := PackedVector3Array()
var _delivered := 0
var _task_package: Package
var _between_shifts := false
var _last_denials := {}


## Starts control mode at the given shift (0-based).
func start(first_shift := 0) -> void:
	for chute: Chute in get_tree().get_nodes_in_group(&"chutes"):
		if not chute.received.is_connected(_on_chute_received):
			chute.received.connect(_on_chute_received.bind(chute))
	active = true
	_shift_index = first_shift - 1
	_next_shift()


## Ends control mode for good.
func release() -> void:
	active = false
	current_step = null
	robot.extension_limit = INF


func get_route() -> PackedVector3Array:
	return _route


func get_delivered() -> int:
	return _delivered


func _physics_process(_delta: float) -> void:
	if not active or _between_shifts or current_step == null:
		return
	if robot.held:
		_task_package = robot.held
	if _is_step_done():
		if current_step.kind == ShiftStep.Kind.ACCIDENT:
			release()
			accident.emit()
			return
		_next_step()


# --- Filters the player controller runs its input through. ---

func filter_move(input: Vector3) -> Vector3:
	if not active or current_step == null:
		return input
	if _between_shifts or not current_step.allow_move:
		if input.length() > 0.1:
			deny("Movement not authorized")
		return Vector3.ZERO
	var pos := _flat(robot.global_position)
	if pos.distance_to(_flat(current_step.global_position)) < current_step.radius:
		return input
	var next := pos + input * lookahead
	var closest := _closest_on_route(next)
	if next.distance_to(closest) <= current_step.corridor_width / 2.0:
		return input
	var outward := (next - closest).normalized()
	var push := input.dot(outward)
	if push > 0.0:
		deny("Off route. Return to your task")
		input -= outward * push
	return input


func filter_arms(wanted: bool) -> bool:
	if not active or current_step == null or not wanted:
		return wanted
	if current_step.allow_arms:
		return true
	deny("Arm extension not authorized")
	return false


func can_grab(package: Package) -> bool:
	if not active or current_step == null or package == null:
		return true
	if package == _task_package:
		return true
	var source := current_step.get_package_source()
	if source and package.source == source:
		return true
	deny("That package is not assigned to you")
	return false


func allows_throw() -> bool:
	return not active or current_step == null or current_step.allow_throw


func can_throw() -> bool:
	if allows_throw():
		return true
	deny("Throwing not authorized")
	return false


func _next_shift() -> void:
	_shift_index += 1
	var shifts := _get_shifts()
	if _shift_index >= shifts.size():
		release()
		return
	current_shift = shifts[_shift_index]
	Quota.reset(current_shift.quota)
	_step_index = -1
	shift_started.emit(current_shift)
	_next_step()


func _next_step() -> void:
	_step_index += 1
	var steps := current_shift.get_steps()
	if _step_index >= steps.size():
		_finish_shift()
		return
	current_step = steps[_step_index]
	robot.extension_limit = current_step.max_extension
	_route = PackedVector3Array([robot.global_position])
	_route.append_array(current_step.get_waypoints())
	_delivered = 0
	step_started.emit(current_step)


func _finish_shift() -> void:
	var finished := current_shift
	current_step = null
	_between_shifts = true
	shift_finished.emit(finished)
	await get_tree().create_timer(shift_break, false, true).timeout
	_between_shifts = false
	if active:
		_next_shift()


func _is_step_done() -> bool:
	var step := current_step
	match step.kind:
		ShiftStep.Kind.REACH, ShiftStep.Kind.ACCIDENT:
			return _flat(robot.global_position).distance_to(_flat(step.global_position)) \
				< step.radius
		ShiftStep.Kind.GRAB:
			return robot.held != null and (step.target == null or robot.held.source == step.target)
		ShiftStep.Kind.DELIVER:
			return _delivered >= step.count
		ShiftStep.Kind.PRESS:
			return (step.target as PushButton).is_pressed
	return false


func _on_chute_received(_package: Package, chute: Chute) -> void:
	if current_step and current_step.kind == ShiftStep.Kind.DELIVER \
			and (current_step.target == null or current_step.target == chute):
		_delivered += 1


## Tells the player an action was blocked. Repeats are throttled.
func deny(reason: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_denials.get(reason, -10000)) < 1500:
		return
	_last_denials[reason] = now
	denied.emit(reason)


func _get_shifts() -> Array[Shift]:
	var shifts: Array[Shift] = []
	for child in get_children():
		if child is Shift:
			shifts.append(child)
	return shifts


func _closest_on_route(point: Vector3) -> Vector3:
	if _route.size() == 1:
		return _flat(_route[0])
	var best := Vector3.ZERO
	var best_distance := INF
	for i in _route.size() - 1:
		var candidate := Geometry3D.get_closest_point_to_segment(
			point, _flat(_route[i]), _flat(_route[i + 1]))
		var distance := candidate.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
