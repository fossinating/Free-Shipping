class_name RouteGuide
extends MeshInstance3D
## Draws the assigned route on the floor and a beacon over the task, the
## way a warehouse management system would show a worker where to go.

@export var program: ControlProgram
@export var color := Color(0.2, 0.9, 1.0)
@export var beacon_height := 4.0

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = color
	_material.no_depth_test = true


func _process(_delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	_mesh.clear_surfaces()
	if not program or not program.active or program.current_step == null:
		return
	var route := program.get_route()
	if route.size() < 2:
		return
	var step := program.current_step
	var lift := Vector3.UP * 0.06
	# Draw from the robot along whatever is left of the route.
	var points := PackedVector3Array([program.robot.global_position + lift])
	var start := _nearest_segment(route, program.robot.global_position)
	for i in range(start + 1, route.size()):
		points.append(Vector3(route[i].x, program.robot.global_position.y, route[i].z) + lift)
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	for point in points:
		_mesh.surface_add_vertex(point)
	_mesh.surface_end()
	var beacon := step.global_position
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	_mesh.surface_add_vertex(beacon)
	_mesh.surface_add_vertex(beacon + Vector3.UP * beacon_height)
	_mesh.surface_end()


static func _nearest_segment(route: PackedVector3Array, point: Vector3) -> int:
	var best := 0
	var best_distance := INF
	for i in route.size() - 1:
		var closest := Geometry3D.get_closest_point_to_segment(point, route[i], route[i + 1])
		var distance := closest.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best
