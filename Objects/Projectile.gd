extends RigidBody

class_name Projectile

export(PackedScene) var particle_scene = preload("res://Particles/Packing Peanut.tscn")
export var particle_count := 16
export var particle_spawn_range := Vector3(1,1,1)
export var damage = 1
var _owner
var active = false

func _ready():
	pass
	#set_physics_process(false)

func _physics_process(_delta):
	if active:
		for body in get_colliding_bodies():
			if body != _owner:
				destroy()
				if body.is_in_group("Damageable"):
					body.damage(damage)
				return

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

func set_collision(should_collide):
	for node in get_children():
		if node is CollisionShape:
			node.disabled = !should_collide
	

