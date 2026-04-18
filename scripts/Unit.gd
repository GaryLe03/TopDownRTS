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
	# Initialize target position
	nav_agent.target_position = global_position

func _physics_process(delta):
	# Force unit to stay on the ground plane
	global_position.y = 0

	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return

	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var current_agent_position: Vector3 = global_position

	# Move towards the next path point, ignoring vertical difference
	var direction = (next_path_position - current_agent_position)
	direction.y = 0
	direction = direction.normalized()

	velocity = direction * 5.0
	move_and_slide()

func move_to(pos: Vector3):
	# Ensure the target is at ground level
	var ground_pos = pos
	ground_pos.y = 0
	nav_agent.target_position = ground_pos
