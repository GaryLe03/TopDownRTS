extends CharacterBody3D

@onready var selection_visual = $SelectionVisual

var is_selected = false:
	set(value):
		is_selected = value
		if selection_visual:
			selection_visual.visible = value

var path: Array[Vector3] = []
var speed = 5.0

func _ready():
	selection_visual.visible = is_selected
	global_position.y = 0

func _physics_process(delta):
	global_position.y = 0

	if path.is_empty():
		velocity = Vector3.ZERO
		return

	var target = path[0]
	var dir = (target - global_position)
	dir.y = 0

	if dir.length() < 0.2:
		path.remove_at(0)
		if path.is_empty():
			velocity = Vector3.ZERO
			return
		target = path[0]
		dir = (target - global_position)
		dir.y = 0

	velocity = dir.normalized() * speed
	move_and_slide()

func move_to(target_pos: Vector3):
	var main = get_tree().root.find_child("Main", true, false)
	if main and main.has_method("get_astar_path"):
		path = main.get_astar_path(global_position, target_pos)
