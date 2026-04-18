extends Node3D

@onready var nav_region = $NavigationRegion3D

func _ready():
	# Ensure the navigation mesh is baked at start to include obstacles.
	# We use a timer to give Godot a bit of time to settle the physics/tree.
	get_tree().create_timer(0.1).timeout.connect(_bake_nav)

func _bake_nav():
	nav_region.bake_navigation_mesh()
