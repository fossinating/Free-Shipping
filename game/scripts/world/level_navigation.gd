class_name LevelNavigation
extends NavigationRegion3D
## Bakes the navigation mesh from the level's static colliders at startup,
## so generated blockout levels don't need a baked mesh checked in. CSG
## blockout is parsed through its meshes, which Godot warns about once;
## that's fine for a one-time bake at load.


func _ready() -> void:
	# CSG shapes build their colliders a frame late.
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_navigation_mesh(false)
