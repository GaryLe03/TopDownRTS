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
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0

	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var current_agent_position: Vector3 = global_position

	# Calculate 2D direction (XZ plane)
	var dir_3d = (next_path_position - current_agent_position)
	var dir_2d = Vector2(dir_3d.x, dir_3d.z).normalized()

	velocity.x = dir_2d.x * 5.0
	velocity.z = dir_2d.y * 5.0

	move_and_slide()

func move_to(pos: Vector3):
	nav_agent.set_target_position(pos)
