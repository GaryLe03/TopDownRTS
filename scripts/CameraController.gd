extends Camera3D

@export var move_speed := 20.0
@export var zoom_speed := 2.0

var selection_start = Vector2.ZERO
var is_dragging = false

@onready var selection_rect = $"../UI/SelectionRect"

func _process(delta):
	_handle_movement(delta)
	_handle_selection()

func _handle_movement(delta):
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	var move_vec = input_dir.normalized() * move_speed * delta
	global_position += move_vec

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				selection_start = event.position
				is_dragging = true
			else:
				is_dragging = false
				selection_rect.visible = false
				_select_units_in_box(selection_start, event.position)

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_move_selected_units(event.position)

func _handle_selection():
	if is_dragging:
		var current_mouse_pos = get_viewport().get_mouse_position()
		if current_mouse_pos.distance_to(selection_start) > 5:
			selection_rect.visible = true
			var rect_pos = Vector2(min(selection_start.x, current_mouse_pos.x), min(selection_start.y, current_mouse_pos.y))
			var rect_size = (selection_start - current_mouse_pos).abs()
			selection_rect.position = rect_pos
			selection_rect.size = rect_size

func _select_units_in_box(start, end):
	var rect = Rect2(min(start.x, end.x), min(start.y, end.y), abs(start.x - end.x), abs(start.y - end.y))

	# If it's a tiny click, treat it as single selection
	var is_single_click = rect.size.length() < 5

	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		var screen_pos = unproject_position(unit.global_position)
		if is_single_click:
			# For single click, we might want raycasting instead,
			# but for now let's use a small radius around mouse
			var mouse_pos = get_viewport().get_mouse_position()
			unit.is_selected = (screen_pos.distance_to(mouse_pos) < 20)
		else:
			unit.is_selected = rect.has_point(screen_pos)

func _move_selected_units(mouse_pos):
	var from = project_ray_origin(mouse_pos)
	var dir = project_ray_normal(mouse_pos)

	# Project onto ground plane (y=0)
	var ground_plane = Plane(Vector3.UP, 0)
	var intersection = ground_plane.intersects_ray(from, dir)

	if intersection != null:
		var target_pos = intersection
		var selected_units = []
		for unit in get_tree().get_nodes_in_group("units"):
			if unit.is_selected:
				selected_units.append(unit)

		# Simple formation (grid-ish)
		var count = selected_units.size()
		if count == 0: return

		var side = ceil(sqrt(count))
		var offset_start = (side - 1) * 1.5 / 2.0
		for i in range(count):
			var x = i % int(side)
			var z = i / int(side)
			var offset = Vector3(x * 1.5 - offset_start, 0, z * 1.5 - offset_start)
			selected_units[i].move_to(target_pos + offset)
