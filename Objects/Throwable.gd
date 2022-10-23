extends Projectile

class_name Throwable


var holder

func _ready():
	_owner = holder

func throw(impulse):
	active = true
	holder = null
	var thrown_from = self.global_transform
	self.get_parent().remove_child(self)
	self.mode = RigidBody.MODE_RIGID
	self.sleeping = false
	Globals.root.add_child(self)
	set_collision(true)
	set_physics_process(true)
	
	self.global_transform = thrown_from
	self.apply_central_impulse(mass/2*impulse)
