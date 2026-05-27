extends Node3D

var astar = AStarGrid2D.new()
var grid_size = Vector2i(800, 800)
var cell_size = 0.5
var offset = Vector2(-200, -200)

func _ready():
	# Wait for a frame to ensure all scene nodes are fully ready and placed
	await get_tree().process_frame
	setup_grid()

func setup_grid():
	astar.region = Rect2i(0, 0, grid_size.x, grid_size.y)
	astar.cell_size = Vector2(cell_size, cell_size)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	# Mark static obstacles as solid
	var obstacle_nodes = get_tree().get_nodes_in_group("obstacles")

	for obstacle in obstacle_nodes:
		var pos = obstacle.global_position
		var grid_pos = world_to_grid(pos)

		# Base obstacle (2x2) uses radius 3 (1.5 units)
		# Buildings (24x24) use radius 25 (12.5 units)
		var cell_radius = 3
		if obstacle.name.begins_with("Building"):
			cell_radius = 25

		for x in range(-cell_radius, cell_radius + 1):
			for y in range(-cell_radius, cell_radius + 1):
				var p = grid_pos + Vector2i(x, y)
				if astar.region.has_point(p):
					astar.set_point_solid(p, true)

	astar.update()

	_setup_unit_ui()
	_setup_ai_pause()

func _setup_ai_pause():
	var btn = find_child("PauseAIButton")
	var ai = find_child("EnemyAI")
	if btn and ai:
		btn.toggled.connect(func(toggled): ai.is_paused = toggled)

func _setup_unit_ui():
	var unit_list = find_child("UnitList")
	if not unit_list: return

	var unit_icon_scene = load("res://scenes/UnitIcon.tscn")
	var units = get_tree().get_nodes_in_group("units")

	for unit in units:
		if unit.team == 0: # Player unit
			var icon = unit_icon_scene.instantiate()
			unit_list.add_child(icon)
			icon.setup(unit)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		round((world_pos.x - offset.x) / cell_size),
		round((world_pos.z - offset.y) / cell_size)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		grid_pos.x * cell_size + offset.x,
		0,
		grid_pos.y * cell_size + offset.y
	)

func get_astar_path(start_world: Vector3, end_world: Vector3, margin: float = 0.4, requester: Node3D = null) -> Array[Vector3]:
	var start_grid = world_to_grid(start_world)
	var end_grid = world_to_grid(end_world)

	if not astar.region.has_point(start_grid) or not astar.region.has_point(end_grid):
		return []

	# Ensure we start and end on non-solid points
	start_grid = _find_nearest_non_solid(start_grid)
	end_grid = _find_nearest_non_solid(end_grid)

	var path_grid = astar.get_id_path(start_grid, end_grid)
	var path_world: Array[Vector3] = []
	for p in path_grid:
		path_world.append(grid_to_world(p))

	# Basic Smoothing Pass
	return smooth_path(path_world, margin, requester)

func smooth_path(path: Array[Vector3], margin: float = 0.4, requester: Node3D = null) -> Array[Vector3]:
	if path.size() <= 2:
		return path

	var smoothed: Array[Vector3] = [path[0]]
	var current_idx = 0

	while current_idx < path.size() - 1:
		var furthest_visible = current_idx + 1
		for i in range(current_idx + 2, path.size()):
			if _has_clear_path(path[current_idx], path[i], margin, requester):
				furthest_visible = i
			else:
				break
		smoothed.append(path[furthest_visible])
		current_idx = furthest_visible

	return smoothed

func _find_nearest_non_solid(center: Vector2i) -> Vector2i:
	if not astar.is_point_solid(center):
		return center

	# Spiral search for nearest non-solid point
	for r in range(1, 30):
		# Top and Bottom rows
		for x in range(-r, r + 1):
			for y in [-r, r]:
				var p = center + Vector2i(x, y)
				if astar.region.has_point(p) and not astar.is_point_solid(p):
					return p
		# Left and Right columns (minus corners)
		for y in range(-r + 1, r):
			for x in [-r, r]:
				var p = center + Vector2i(x, y)
				if astar.region.has_point(p) and not astar.is_point_solid(p):
					return p
	return center

func _has_clear_path(a: Vector3, b: Vector3, margin: float = 0.4, requester: Node3D = null) -> bool:
	var space_state = get_world_3d().direct_space_state
	var start = a + Vector3(0, 0.5, 0)
	var end = b + Vector3(0, 0.5, 0)

	var dir = (end - start).normalized()
	var side = Vector3(-dir.z, 0, dir.x)

	# For larger margins, use more rays to ensure we don't skip narrow obstacles
	var ray_count = 3
	if margin > 0.8:
		ray_count = 5

	var offsets = []
	if ray_count == 3:
		offsets = [Vector3.ZERO, side * margin, -side * margin]
	else:
		offsets = [
			Vector3.ZERO,
			side * margin,
			-side * margin,
			side * (margin * 0.5),
			-side * (margin * 0.5)
		]

	for offset in offsets:
		var query = PhysicsRayQueryParameters3D.create(start + offset, end + offset)
		if requester:
			query.exclude = [requester]
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			return false
	return true
