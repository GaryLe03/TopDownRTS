extends Node3D

@onready var nav_region = $NavigationRegion3D

func _ready():
	# Ensure the navigation mesh is baked at start to include obstacles.
	# We use call_deferred to ensure all nodes are fully in the tree.
	call_deferred("_bake_nav")

func _bake_nav():
	nav_region.bake_navigation_mesh()
