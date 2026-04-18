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
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return

	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var current_agent_position: Vector3 = global_position
	var new_velocity: Vector3 = (next_path_position - current_agent_position).normalized() * 5.0

	velocity = new_velocity
	move_and_slide()

func move_to(pos: Vector3):
	nav_agent.set_target_position(pos)
