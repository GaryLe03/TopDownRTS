extends Node3D

@onready var nav_region = $NavigationRegion3D

func _ready():
	# Bake navigation mesh at start so it includes obstacles
	nav_region.bake_navigation_mesh()
