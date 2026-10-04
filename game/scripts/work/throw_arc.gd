class_name ThrowArc
extends MeshInstance3D
## Draws the predicted path of a throw so players can aim.

const STEP := 1.0 / 30.0
const MAX_TIME := 3.0

@export var color := Color(1.0, 0.85, 0.3)

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = color
	_material.no_depth_test = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()


## Points along a ballistic path, ending where it first hits something.
static func predict(space: PhysicsDirectSpaceState3D, from: Vector3, launch_velocity: Vector3,
		gravity: Vector3, exclude: Array[RID] = []) -> PackedVector3Array:
	var points := PackedVector3Array([from])
	var current := from
	var velocity := launch_velocity
	var time := 0.0
	while time < MAX_TIME:
		velocity += gravity * STEP
		var next := current + velocity * STEP
		var query := PhysicsRayQueryParameters3D.create(current, next, 1, exclude)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			points.append(hit.position)
			return points
		points.append(next)
		current = next
		time += STEP
	return points


func draw(points: PackedVector3Array) -> void:
	global_transform = Transform3D.IDENTITY
	_mesh.clear_surfaces()
	if points.size() < 2:
		hide()
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	for point in points:
		_mesh.surface_add_vertex(point)
	_mesh.surface_end()
	# A small cross where it lands.
	var end := points[points.size() - 1]
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for axis: Vector3 in [Vector3(0.3, 0, 0), Vector3(0, 0, 0.3)]:
		_mesh.surface_add_vertex(end - axis)
		_mesh.surface_add_vertex(end + axis)
	_mesh.surface_end()
	show()
