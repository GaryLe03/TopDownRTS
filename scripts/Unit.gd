extends CharacterBody3D

@onready var selection_visual = $SelectionVisual
@onready var nav_agent = $NavigationAgent3D

var is_selected = false:
	set(value):
		is_selected = value
		if selection_visual:
			selection_visual.visible = value

var target_position = Vector3.ZERO

func _ready():
	selection_visual.visible = is_selected
	target_position = global_position

func _physics_process(delta):
	if global_position.distance_to(target_position) > 0.1:
		var direction = (target_position - global_position).normalized()
		velocity = direction * 5.0
		move_and_slide()
	else:
		velocity = Vector3.ZERO

func move_to(pos: Vector3):
	target_position = pos
