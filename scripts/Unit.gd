extends CharacterBody3D

@onready var selection_visual = $SelectionVisual

var is_selected = false:
	set(value):
		is_selected = value
		if selection_visual:
			selection_visual.visible = value

var path: Array[Vector3] = []
var speed = 5.0
var stuck_timer = 0.0
var last_pos = Vector3.ZERO

func _ready():
	selection_visual.visible = is_selected
	global_position.y = 0

func _physics_process(delta):
	global_position.y = 0

	if path.is_empty():
		velocity = Vector3.ZERO
		stuck_timer = 0.0
		return

	var target = path[0]
	var dir = (target - global_position)
	dir.y = 0

	# Stuck detection
	if global_position.distance_to(last_pos) < 0.01:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_pos = global_position

	if dir.length() < 0.3 or stuck_timer > 0.5:
		path.remove_at(0)
		stuck_timer = 0.0
		if path.is_empty():
			velocity = Vector3.ZERO
			return
		target = path[0]
		dir = (target - global_position)
		dir.y = 0

	velocity = dir.normalized() * speed
	move_and_slide()

func move_to(target_pos: Vector3):
	var main = get_tree().current_scene
	if main and main.has_method("get_astar_path"):
		var new_path = main.get_astar_path(global_position, target_pos)

		# Prevent 'snap-back' to the center of the current grid cell
		# If the first point in the path is very close to current position, skip it
		if new_path.size() > 1:
			var first_point = new_path[0]
			var dist_to_first = (first_point - global_position)
			dist_to_first.y = 0
			if dist_to_first.length() < 0.4: # Cell size is 0.5, so 0.4 is safe
				new_path.remove_at(0)

		path = new_path
