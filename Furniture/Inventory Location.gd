extends Position3D

class_name InventoryLocation

var inventory = null

func is_free():
	return inventory != null

func set_inventory(_inventory):
	self.inventory = _inventory
