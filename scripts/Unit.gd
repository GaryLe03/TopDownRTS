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
	var pos_2d = Vector2(global_position.x, global_position.z)
	var target_2d = Vector2(target_position.x, target_position.z)

	if pos_2d.distance_to(target_2d) > 0.1:
		var direction_2d = (target_2d - pos_2d).normalized()
		velocity.x = direction_2d.x * 5.0
		velocity.z = direction_2d.y * 5.0
		velocity.y = 0 # Ensure we stay on ground
		move_and_slide()
	else:
		velocity = Vector3.ZERO

func move_to(pos: Vector3):
	target_position = pos
