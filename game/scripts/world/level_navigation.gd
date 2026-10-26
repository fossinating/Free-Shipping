class_name LevelNavigation
extends NavigationRegion3D
## Bakes the navigation mesh from the level's static colliders at startup,
## so generated blockout levels don't need a baked mesh checked in.


func _ready() -> void:
	# Wait for the level's colliders to be in the physics space.
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_navigation_mesh(false)
	# Baking fills the region's NavigationMesh resource, but the polygons
	# don't always reach the NavigationServer (they never did when the game
	# loaded a level), leaving every path query empty. Hand them over again a
	# frame later; doing it in the same frame as the bake doesn't take.
	await get_tree().physics_frame
	NavigationServer3D.region_set_navigation_mesh(get_rid(), navigation_mesh)
