class_name RobotBody
extends CharacterBody3D
## A warehouse robot: treads, a telescoping torso, a core, and two
## extending arms. Whoever drives the body (the player, control mode, or an
## AI) only writes the intent variables; the body handles the physics.
##
## Climbing: grow until your core is level with a ledge, extend your arms to
## hook it, then shrink. While hooked, shrinking pulls your treads up instead
## of lowering your core, and once fully shrunk you mantle onto the ledge.
##
## Body upgrades are switched on by whoever drives the body: `wheels` (the
## wheel base: faster, rides conveyors fast, launches off ramps) and
## `magnetic_hands` (cling to metal shelving at any height and climb it).

signal hooked
signal released
signal mantled
signal grabbed(package: Package)
signal let_go(package: Package)
## Took a blow (see knock_back).
signal knocked_back
## Left the ground off a ramp.
signal launched

const TREAD_HEIGHT := 0.4
const MIN_LEG := 0.2
const CORE_HEIGHT := 0.8
const CORE_HALF_DEPTH := 0.4
const HAND_SIZE := 0.15
## Hooking only happens when a ledge top is within this band around the core.
const LEDGE_BELOW_CORE := 0.6
const LEDGE_ABOVE_CORE := 0.5
const MANTLE_TIME := 0.22
## How close to the wall the body hangs, measured from its center.
const HANG_DISTANCE := 0.55
## Nodes in this group are metal: magnetic hands stick to them.
const METAL_GROUP := &"metal"

@export_group("Movement")
@export var move_speed := 6.0
## Speed multiplier at full height; tall robots are top-heavy.
@export var tall_speed_factor := 0.55
@export var acceleration := 45.0
@export var air_acceleration := 8.0
@export var gravity := 24.0
@export var turn_speed := 14.0
## With the wheel base, the body moves this much faster...
@export var wheel_speed_factor := 1.5
## ...and conveyors carry it this much faster than their belt speed.
@export var wheel_belt_factor := 2.5
## Magnetic hands climb metal this fast, in m/s.
@export var magnetic_climb_speed := 2.5

@export_group("Torso")
@export var start_extension := 0.4
@export var max_extension := 5.0
## How fast holding grow/shrink moves the target height, in m/s.
@export var extension_rate := 7.0
## How quickly the torso eases toward the target. Higher is snappier.
@export var extension_smoothing := 16.0

@export_group("Arms")
@export var max_arm_reach := 2.2
@export var arm_rate := 12.0
@export var arm_smoothing := 22.0

@export_group("Carrying")
## Grab reach past the front of the core with the arms in. Extending the
## arms reaches up to max_arm_reach instead.
@export var short_grab_reach := 0.9
## How far below and above the core a package can be and still be grabbed.
@export var grab_below := 1.5
@export var grab_above := 0.8
## Packages within this angle of straight ahead can be grabbed.
@export var grab_cone_degrees := 55.0
## How hard walking into loose packages pushes them, in m/s² (floor
## friction on cardboard is about 9).
@export var push_strength := 14.0
## How fast a grabbed package is pulled into the hands.
@export var carry_smoothing := 25.0

## Desired horizontal movement in world space, length <= 1.
var move_input := Vector3.ZERO
## -1 to shrink, +1 to grow.
var extension_input := 0.0
## True while the arms should reach out.
var arms_input := false
## Yaw the body turns toward. Ignored while hooked.
var facing_yaw := 0.0
## Highest torso extension currently allowed. Control mode lowers this to
## keep robots at company standard height; the torso shrinks to obey it.
var extension_limit := INF

var extension := 0.0
var arm_extension := 0.0
var is_hooked := false
var is_mantling := false
var held: Package = null
## When this robot last hit or was hit by something, in seconds since start.
## Being seen fighting is suspicious.
var last_fight_time := -INF
## Seconds left before a knocked-back robot can move again.
var stun_time := 0.0
## The wheel base upgrade is installed.
var wheels := false
## The magnetic hands upgrade is installed.
var magnetic_hands := false
## Flying off a ramp: keeps its momentum until it lands.
var is_launched := false
## Hooked onto a metal face by magnetic hands, not onto a ledge.
var is_clinging := false

var _target_extension := 0.0
var _target_arm := 0.0
var _hang_point := Vector3.ZERO
var _hang_normal := Vector3.ZERO
var _hang_core_y := 0.0
var _query_boxes := {}
## Set by conveyors each physics frame the body rides one.
var _belt_velocity := Vector3.ZERO
var _belt_frames := 0

@onready var _treads_shape: CollisionShape3D = $TreadsShape
@onready var _leg_shape: CollisionShape3D = $LegShape
@onready var _core_shape: CollisionShape3D = $CoreShape
@onready var _leg_mesh: Node3D = $Visual/Leg
@onready var _core_visual: Node3D = $Visual/Core
@onready var _left_arm: Node3D = $Visual/Core/LeftArm
@onready var _right_arm: Node3D = $Visual/Core/RightArm


func _ready() -> void:
	add_to_group(&"robots")
	# Each robot resizes its own leg, so it needs its own shape.
	_leg_shape.shape = _leg_shape.shape.duplicate()
	for shape_node: CollisionShape3D in [_treads_shape, _leg_shape, _core_shape]:
		_query_boxes[shape_node] = BoxShape3D.new()
	extension = clampf(start_extension, 0.0, max_extension)
	_target_extension = extension
	facing_yaw = rotation.y
	_apply_shape()


func _physics_process(delta: float) -> void:
	if is_mantling:
		return
	stun_time = maxf(0.0, stun_time - delta)
	_update_facing(delta)
	_update_extension(delta)
	_update_arms(delta)
	if is_hooked:
		_process_hanging()
	else:
		_process_moving(delta)
	_carry(delta)
	_apply_shape()


## Total height from the bottom of the treads to the top of the core.
func get_height() -> float:
	return TREAD_HEIGHT + MIN_LEG + extension + CORE_HEIGHT


func get_core_position() -> Vector3:
	return global_position + Vector3.UP * _core_offset(extension)


func get_forward() -> Vector3:
	return -global_basis.z


## Where the hands are, at the tip of the arms.
func get_hand_position() -> Vector3:
	return get_core_position() + get_forward() * (CORE_HALF_DEPTH + arm_extension)


## True when the arms could hook a ledge right now if they were extended.
func is_ledge_in_reach() -> bool:
	return not _find_ledge(max_arm_reach).is_empty()


## True when magnetic hands could cling to metal in front right now.
func is_metal_in_reach() -> bool:
	return not _find_metal(max_arm_reach).is_empty()


## Where a held package sits: just in front of the core.
func get_hold_position() -> Vector3:
	var depth := held.size.z / 2.0 if held else 0.3
	return get_core_position() + get_forward() * (CORE_HALF_DEPTH + 0.1 + depth) \
		+ Vector3.DOWN * 0.1


## The package the hands would grab right now, or null. Pass a reach to
## ask about a different arm length than the current one.
func find_grab_target(arm_reach := -1.0) -> Package:
	if held or is_hooked:
		return null
	var core := get_core_position()
	var forward := get_forward()
	var reach := CORE_HALF_DEPTH + (arm_reach if arm_reach >= 0.0 else get_grab_reach())
	var best: Package = null
	var best_score := INF
	for package: Package in get_tree().get_nodes_in_group(&"packages"):
		if package.is_held():
			continue
		var offset := package.global_position - core
		if offset.y < -grab_below or offset.y > grab_above:
			continue
		var flat := Vector3(offset.x, 0.0, offset.z)
		var distance := flat.length()
		if distance > reach + package.size.z / 2.0:
			continue
		var angle := forward.angle_to(flat) if distance > 0.01 else 0.0
		# Right up against the robot, direction doesn't matter.
		if distance > 0.9 and angle > deg_to_rad(grab_cone_degrees):
			continue
		var hit := _ray(core, package.global_position)
		if not hit.is_empty() and hit.collider != package:
			continue
		var score := distance + angle
		if score < best_score:
			best_score = score
			best = package
	return best


## How far past the core the hands can grab right now.
func get_grab_reach() -> float:
	return max_arm_reach if arms_input else short_grab_reach


func grab(package: Package) -> void:
	if held or package == null or package.is_held():
		return
	held = package
	package.attach(self)
	add_collision_exception_with(package)
	grabbed.emit(package)


## Lets go of the held package, giving it this velocity.
func throw(launch_velocity: Vector3) -> void:
	if not held:
		return
	var package := held
	held = null
	package.global_position = _free_spot_for(package)
	package.detach(launch_velocity, self)
	let_go.emit(package)
	# Don't collide with the package until it has cleared the body.
	get_tree().create_timer(0.3).timeout.connect(_end_collision_exception.bind(package))


func _end_collision_exception(package: Variant) -> void:
	if is_instance_valid(package):
		remove_collision_exception_with(package)


## Sets the held package down in front of the robot.
func drop() -> void:
	throw(Vector3(velocity.x, 0.0, velocity.z))


func is_stunned() -> bool:
	return stun_time > 0.0


## Hit by something: lets go of whatever it holds, gets shoved by `push`
## (m/s, horizontal) and can't move for `stun_seconds`.
func knock_back(push: Vector3, stun_seconds: float) -> void:
	release()
	if held:
		drop()
	velocity = Vector3(push.x, 3.0, push.z)
	stun_time = maxf(stun_time, stun_seconds)
	knocked_back.emit()


## A conveyor under the body moves it along at `belt` (m/s) this frame.
## Wheels ride it faster.
func ride_belt(belt: Vector3) -> void:
	_belt_velocity = belt * (wheel_belt_factor if wheels else 1.0)
	_belt_frames = 2


## Throws the body into the air at `launch_velocity` (a ramp). It keeps
## that momentum until it lands.
func launch(launch_velocity: Vector3) -> void:
	release()
	velocity = launch_velocity
	is_launched = true
	launched.emit()


## Pulls the arms back and drops off a ledge if hooked.
func release() -> void:
	if not is_hooked:
		return
	is_hooked = false
	is_clinging = false
	_target_arm = 0.0
	released.emit()


func _core_offset(ext: float) -> float:
	return TREAD_HEIGHT + MIN_LEG + ext + CORE_HEIGHT / 2.0


func _update_facing(delta: float) -> void:
	if is_hooked or is_stunned():
		return
	rotation.y = lerp_angle(rotation.y, facing_yaw, 1.0 - exp(-turn_speed * delta))


func _update_extension(delta: float) -> void:
	if is_clinging and extension_input > 0.0:
		# Growing while clinging to metal climbs instead (see _climb_metal).
		return
	_target_extension = clampf(_target_extension + extension_input * extension_rate * delta,
		0.0, minf(max_extension, extension_limit))
	var next := lerpf(extension, _target_extension, 1.0 - exp(-extension_smoothing * delta))
	if absf(next - _target_extension) < 0.001:
		next = _target_extension
	if is_equal_approx(next, extension):
		return
	if is_hooked:
		# The hands hold the core in place, so the treads move instead.
		var next_pos := global_position
		next_pos.y = _hang_core_y - _core_offset(next)
		if _fits(next_pos, next):
			global_position = next_pos
			extension = next
		else:
			_target_extension = extension
	elif next < extension or _fits(global_position, next):
		extension = next
	else:
		# Something is overhead; stop growing where we are.
		_target_extension = extension


func _update_arms(delta: float) -> void:
	if held:
		var reach := _flat_distance(get_core_position(), held.global_position)
		arm_extension = maxf(reach - CORE_HALF_DEPTH - held.size.z / 2.0, 0.0)
		return
	if is_hooked:
		if not arms_input:
			release()
		return
	_target_arm = max_arm_reach if arms_input else 0.0
	arm_extension = lerpf(arm_extension, _target_arm, 1.0 - exp(-arm_smoothing * delta))
	arm_extension = minf(arm_extension, _free_reach())
	if arms_input and arm_extension > 0.2 and not held:
		var ledge := _find_ledge(arm_extension)
		if not ledge.is_empty():
			_hook(ledge)
		elif magnetic_hands:
			var metal := _find_metal(arm_extension)
			if not metal.is_empty():
				_hook(metal)
				is_clinging = true


func _process_moving(delta: float) -> void:
	var height_t := extension / max_extension if max_extension > 0.0 else 0.0
	var speed := move_speed * lerpf(1.0, tall_speed_factor, height_t)
	if wheels:
		speed *= wheel_speed_factor
	var target := Vector3.ZERO if is_stunned() else move_input.limit_length(1.0) * speed
	if _belt_frames > 0:
		_belt_frames -= 1
		if is_on_floor():
			target += _belt_velocity
	var accel := acceleration if is_on_floor() else air_acceleration
	if is_launched:
		if is_on_floor() and velocity.y <= 0.0:
			is_launched = false
		else:
			# Ballistic: no braking in the air.
			accel = 0.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_push_packages(delta)


func _push_packages(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body and not body.freeze:
			var push := -collision.get_normal()
			push.y = 0.0
			body.apply_impulse(push.normalized() * push_strength * body.mass * delta,
				collision.get_position() - body.global_position)


func _carry(delta: float) -> void:
	if not held:
		return
	if not is_instance_valid(held):
		held = null
		return
	var weight := 1.0 - exp(-carry_smoothing * delta)
	held.global_position = held.global_position.lerp(get_hold_position(), weight)
	held.global_basis = held.global_basis.slerp(global_basis, weight).orthonormalized()


## The hold position if the package fits there, otherwise on top of the core.
func _free_spot_for(package: Package) -> Vector3:
	var spot := get_hold_position()
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = package.size - Vector3.ONE * 0.04
	query.shape = box
	query.transform = Transform3D(global_basis, spot)
	query.collision_mask = collision_mask
	query.exclude = [get_rid(), package.get_rid()]
	if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return spot
	return get_core_position() + Vector3.UP * (CORE_HEIGHT / 2.0 + package.size.y / 2.0 + 0.05)


func _process_hanging() -> void:
	velocity = Vector3.ZERO
	# Pushing away from the wall lets go.
	if move_input.dot(_hang_normal) > 0.5:
		release()
		return
	_reel_in()
	if is_clinging:
		_climb_metal()
	if extension <= 0.001 and extension_input < 0.0 and not is_clinging:
		_try_mantle()


func _hook(ledge: Dictionary) -> void:
	is_hooked = true
	_hang_point = ledge.point
	_hang_normal = ledge.normal
	_hang_core_y = get_core_position().y
	velocity = Vector3.ZERO
	rotation.y = atan2(_hang_normal.x, _hang_normal.z)
	facing_yaw = rotation.y
	arm_extension = clampf(
		_flat_distance(global_position, _hang_point) - CORE_HALF_DEPTH, 0.0, max_arm_reach)
	hooked.emit()


## Retracting arms pull the body up against the wall.
func _reel_in() -> void:
	var distance := _flat_distance(global_position, _hang_point)
	var step := minf(arm_rate * get_physics_process_delta_time(), distance - HANG_DISTANCE)
	if step > 0.001:
		var next_pos := global_position - _hang_normal * step
		if _fits(next_pos, extension):
			global_position = next_pos
			distance -= step
	arm_extension = maxf(distance - CORE_HALF_DEPTH, 0.0)


func _try_mantle() -> void:
	var top := _hang_point - _hang_normal * (CORE_HALF_DEPTH + 0.25)
	top.y = _hang_point.y + 0.02
	var raised := global_position
	raised.y = top.y
	if not _fits(top, extension):
		return
	is_mantling = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", raised, MANTLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", top, MANTLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "arm_extension", 0.0, MANTLE_TIME)
	tween.tween_callback(_finish_mantle)


func _finish_mantle() -> void:
	is_mantling = false
	is_hooked = false
	_target_arm = 0.0
	velocity = Vector3.ZERO
	mantled.emit()


## Magnetic hands on a metal face: growing climbs it. Once the top comes
## within reach, the hands hook it like any ledge, so shrinking mantles.
func _climb_metal() -> void:
	var ledge := _find_ledge(max_arm_reach)
	if not ledge.is_empty():
		is_clinging = false
		_hang_point = ledge.point
		_hang_normal = ledge.normal
		return
	if extension_input <= 0.0:
		return
	var step := magnetic_climb_speed * get_physics_process_delta_time()
	var next_pos := global_position + Vector3.UP * step
	# Only while there's still metal in front of the hands.
	if _fits(next_pos, extension) and not _find_metal(max_arm_reach, step).is_empty():
		global_position = next_pos
		_hang_core_y += step
		_hang_point.y += step


## A metal face in front of the hands, as a hook point at core height.
func _find_metal(reach: float, lift := 0.0) -> Dictionary:
	var core := get_core_position() + Vector3.UP * lift
	var wall := _ray(core, core + get_forward() * (CORE_HALF_DEPTH + reach + HAND_SIZE))
	if wall.is_empty() or absf(wall.normal.y) > 0.3:
		return {}
	var collider := wall.collider as Node
	if collider == null or not collider.is_in_group(METAL_GROUP):
		return {}
	return {"point": wall.position, "normal": Vector3(wall.normal.x, 0.0, wall.normal.z).normalized()}


## How far the arms can reach before the hands touch something.
func _free_reach() -> float:
	var core := get_core_position()
	var hit := _ray(core, core + get_forward() * (CORE_HALF_DEPTH + max_arm_reach + HAND_SIZE))
	if hit.is_empty():
		return max_arm_reach
	return clampf(_flat_distance(core, hit.position) - CORE_HALF_DEPTH - HAND_SIZE,
		0.0, max_arm_reach)


## Looks for a wall in front of the hands with a walkable top near core height.
func _find_ledge(reach: float) -> Dictionary:
	var core := get_core_position()
	var forward := get_forward()
	var probe_y := core.y - LEDGE_BELOW_CORE + 0.05
	var from := Vector3(core.x, probe_y, core.z)
	var wall := _ray(from, from + forward * (CORE_HALF_DEPTH + reach + HAND_SIZE))
	if wall.is_empty() or absf(wall.normal.y) > 0.3:
		return {}
	var normal: Vector3 = Vector3(wall.normal.x, 0.0, wall.normal.z).normalized()
	var above: Vector3 = wall.position - normal * 0.2
	above.y = core.y + LEDGE_ABOVE_CORE
	var top := _ray(above, Vector3(above.x, probe_y, above.z))
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var point: Vector3 = wall.position
	point.y = top.position.y
	return {"point": point, "normal": normal}


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


## Whether the body would fit at the given position and torso extension.
func _fits(pos: Vector3, ext: float) -> bool:
	var space := get_world_3d().direct_space_state
	var basis_now := global_basis
	var layout := _shape_layout(ext)
	for shape_node: CollisionShape3D in layout:
		var info: Dictionary = layout[shape_node]
		# Shrink the sides and lift the bottom slightly so touching a wall or
		# resting on the floor is fine; the top stays exact for ceilings.
		var box: BoxShape3D = _query_boxes[shape_node]
		box.size = (info.size as Vector3) - Vector3(0.06, 0.02, 0.06)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = box
		query.transform = Transform3D(basis_now, pos + Vector3.UP * ((info.y as float) + 0.01))
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true


func _shape_layout(ext: float) -> Dictionary:
	var leg_length := MIN_LEG + ext
	return {
		_treads_shape: {"y": TREAD_HEIGHT / 2.0, "size": (_treads_shape.shape as BoxShape3D).size},
		_leg_shape: {"y": TREAD_HEIGHT + leg_length / 2.0,
			"size": Vector3(0.3, leg_length, 0.3)},
		_core_shape: {"y": _core_offset(ext), "size": (_core_shape.shape as BoxShape3D).size},
	}


func _apply_shape() -> void:
	var leg_length := MIN_LEG + extension
	(_leg_shape.shape as BoxShape3D).size = Vector3(0.3, leg_length, 0.3)
	_leg_shape.position.y = TREAD_HEIGHT + leg_length / 2.0
	_core_shape.position.y = _core_offset(extension)
	_leg_mesh.scale.y = leg_length
	_leg_mesh.position.y = TREAD_HEIGHT + leg_length / 2.0
	_core_visual.position.y = _core_offset(extension)
	for arm: Node3D in [_left_arm, _right_arm]:
		arm.get_node("Segment").scale.z = maxf(arm_extension, 0.01)
		arm.get_node("Segment").position.z = -arm_extension / 2.0
		arm.get_node("Hand").position.z = -arm_extension - HAND_SIZE / 2.0


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
