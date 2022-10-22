extends Spatial


var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()


func get_item():
	return get_child(rng.randi_range(0, get_child_count() - 1))
