class_name GuardBrain
extends Node
## A security robot. Patrols, investigates noises and check-ins, and hunts
## the player during a lockdown. Pathfinds with a NavigationAgent3D.

enum State { PATROL, INVESTIGATE, CHECK_IN, CHASE, SEARCH }

@export var route: Node3D
@export var wait_time := 1.5
@export var patrol_speed := 0.5
@export var look_around_time := 3.0
## How long a lockdown search keeps picking nearby spots.
@export var search_time := 10.0
@export var search_radius := 8.0
@export var catch_distance := 1.5
@export var check_in_distance := 2.5

var state := State.PATROL
var target_position := Vector3.ZERO

var _points := PackedVector3Array()
var _index := 0
var _wait := 0.0
var _search_left := 0.0

@onready var robot: RobotBody = get_parent()
@onready var _agent: NavigationAgent3D = $"../Agent"
@onready var _eyes: Watcher = $"../Visual/Core/Eyes"


func _ready() -> void:
	robot.add_to_group(&"guards")
	if route:
		for child in route.get_children():
			if child is Node3D:
				_points.append((child as Node3D).global_position)
	Security.lockdown_started.connect(_on_lockdown_started)
	Security.lockdown_ended.connect(func() -> void: _set_state(State.PATROL))
	Security.sighted.connect(_on_sighted)
	Security.noise.connect(_on_noise)
	Security.check_in_requested.connect(_on_check_in_requested)


func _physics_process(delta: float) -> void:
	robot.move_input = Vector3.ZERO
	var player := _eyes.target
	if Security.lockdown and player and _eyes.sees_target:
		_set_state(State.CHASE, player.global_position)
	match state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			if _arrive(target_position, patrol_speed, 1.0):
				_look_around(delta, State.PATROL)
		State.CHECK_IN:
			if not player or _arrive(player.global_position, patrol_speed, check_in_distance):
				if player:
					_face(player.global_position - robot.global_position)
				_look_around(delta, State.PATROL)
		State.CHASE:
			if player and _eyes.sees_target:
				target_position = player.global_position
			if player and Security.lockdown \
					and robot.global_position.distance_to(player.global_position) < catch_distance:
				Security.catch_player()
				_set_state(State.PATROL)
			elif _arrive(target_position, 1.0, 0.8):
				_set_state(State.SEARCH, target_position)
		State.SEARCH:
			_search_left -= delta
			if _arrive(target_position, 0.8, 1.0):
				if _search_left <= 0.0 or not Security.lockdown:
					_look_around(delta, State.PATROL)
				else:
					_wait -= delta
					robot.facing_yaw += delta * 2.0
					if _wait <= 0.0:
						_pick_search_point()


## Whether the guard is in the middle of something other than its patrol.
func is_busy() -> bool:
	return state != State.PATROL


func _set_state(new_state: State, at := Vector3.ZERO) -> void:
	state = new_state
	target_position = at
	_wait = look_around_time
	if new_state == State.SEARCH:
		_search_left = search_time
		_wait = 1.0


func _patrol(delta: float) -> void:
	if _points.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if _arrive(_points[_index], patrol_speed, 0.6):
		_index = (_index + 1) % _points.size()
		_wait = wait_time


func _look_around(delta: float, then: State) -> void:
	_wait -= delta
	robot.facing_yaw += delta * 1.5
	if _wait <= 0.0:
		_set_state(then)


func _pick_search_point() -> void:
	var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * search_radius
	var map := _agent.get_navigation_map()
	target_position = NavigationServer3D.map_get_closest_point(map, target_position + offset)
	_wait = 1.0


## Walks toward a point. Returns true once within `distance` of it.
func _arrive(point: Vector3, speed: float, distance: float) -> bool:
	var to_goal := point - robot.global_position
	to_goal.y = 0.0
	if to_goal.length() <= distance:
		return true
	var next := point
	if NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0:
		if _agent.target_position.distance_to(point) > 0.5:
			_agent.target_position = point
		next = _agent.get_next_path_position()
	var direction := next - robot.global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		direction = to_goal
	robot.move_input = direction.normalized() * speed
	_face(direction)
	return false


func _face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		robot.facing_yaw = atan2(-direction.x, -direction.z)


func _on_lockdown_started() -> void:
	_set_state(State.SEARCH, Security.last_known_position)


func _on_sighted(position: Vector3) -> void:
	if state != State.CHASE:
		_set_state(State.SEARCH, position)


func _on_noise(position: Vector3, radius: float) -> void:
	if state == State.CHASE or robot.global_position.distance_to(position) > radius:
		return
	if Security.lockdown:
		_set_state(State.SEARCH, position)
	elif state == State.PATROL:
		_set_state(State.INVESTIGATE, position)


func _on_check_in_requested() -> void:
	# Only the nearest idle guard goes.
	var player := _eyes.target
	if player == null or is_busy():
		return
	var mine := robot.global_position.distance_to(player.global_position)
	for guard: RobotBody in get_tree().get_nodes_in_group(&"guards"):
		var brain := guard.get_node_or_null("Brain") as GuardBrain
		if guard != robot and brain and not brain.is_busy() \
				and guard.global_position.distance_to(player.global_position) < mine:
			return
	_set_state(State.CHECK_IN)
