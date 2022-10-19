extends RigidBody

class_name Throwable

export(PackedScene) var particle_scene = preload("res://Particles/Packing Peanut.tscn")
export var particle_count := 16
export var particle_spawn_range := Vector3(1,1,1)

func _ready():
	set_physics_process(false)

func throw(impulse):
	print("thrown")
	var root = get_tree().root
	var thrown_from = self.global_transform
	self.get_parent().remove_child(self)
	root.get_child(0).add_child(self)
	self.get_node("CollisionShape").disabled = false
	set_physics_process(true)
	
	self.global_transform = thrown_from
	self.apply_central_impulse(impulse)

func _physics_process(delta):
	if (get_colliding_bodies().size() != 0):
		print(get_colliding_bodies().size())
	if get_colliding_bodies().size() > 0:
		destroy()

func destroy():
	var rand = RandomNumberGenerator.new()
	rand.randomize()
	for i in particle_count:
		var particle_instance = particle_scene.instance()
		self.get_parent().add_child(particle_instance)
		particle_instance.global_transform.origin = self.global_transform.origin + Vector3(
			rand.randf_range(-particle_spawn_range.x, particle_spawn_range.x),
			rand.randf_range(-particle_spawn_range.y, particle_spawn_range.y),
			rand.randf_range(-particle_spawn_range.z, particle_spawn_range.z)
		)
		particle_instance.rotation = Vector3(rand.randf(), rand.randf(), rand.randf())
		
	self.get_parent().remove_child(self)
	queue_free()
