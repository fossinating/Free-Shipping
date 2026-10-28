class_name ThrowArc
extends MeshInstance3D
## Draws the predicted path of a throw so players can aim.

const STEP := 1.0 / 30.0
const MAX_TIME := 3.0

@export var color := Color(1.0, 0.85, 0.3)
## Radius of the ring drawn where the throw lands. Big enough to read from
## behind the robot, and drawn over everything.
@export var marker_radius := 0.55

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _marker := MeshInstance3D.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = color
	_material.no_depth_test = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := TorusMesh.new()
	ring.inner_radius = marker_radius * 0.75
	ring.outer_radius = marker_radius
	ring.rings = 32
	ring.ring_segments = 6
	var marker_material := _material.duplicate() as StandardMaterial3D
	marker_material.render_priority = 1
	ring.material = marker_material
	_marker.mesh = ring
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
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
	# A cross and a ring where it lands, lying on whatever it hits.
	var end := points[points.size() - 1]
	var normal := _landing_normal(points)
	var flat := Basis(Quaternion(Vector3.UP, normal)) if normal.y > -0.99 \
		else Basis(Vector3.RIGHT, PI)
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	for axis: Vector3 in [Vector3(0.3, 0, 0), Vector3(0, 0, 0.3)]:
		_mesh.surface_add_vertex(end - flat * axis)
		_mesh.surface_add_vertex(end + flat * axis)
	_mesh.surface_end()
	_marker.global_transform = Transform3D(flat, end + normal * 0.03)
	show()


## The surface normal where the path ends, or up if it ends in mid-air.
func _landing_normal(points: PackedVector3Array) -> Vector3:
	var last := points[points.size() - 1]
	var before := points[points.size() - 2]
	var step := (last - before).normalized() * 0.1
	var query := PhysicsRayQueryParameters3D.create(before, last + step, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.normal if not hit.is_empty() else Vector3.UP
