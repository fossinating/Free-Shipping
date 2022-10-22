extends InventoryLocation


export (NodePath)var location1
export (NodePath)var location2

func is_free():
	return location1.is_free() and location2.is_free()

func set_inventory(inventory):
	self.inventory = inventory
	location1.set_inventory(inventory)
	location1.set_inventory(inventory)
