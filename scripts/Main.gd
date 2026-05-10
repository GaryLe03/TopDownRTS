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
		# Buildings (24x24) use radius 26 (13 units)
		var cell_radius = 3
		if obstacle.name.begins_with("Building"):
			cell_radius = 26

		for x in range(-cell_radius, cell_radius + 1):
			for y in range(-cell_radius, cell_radius + 1):
				var p = grid_pos + Vector2i(x, y)
				if astar.region.has_point(p):
					astar.set_point_solid(p, true)

	astar.update()

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

func get_astar_path(start_world: Vector3, end_world: Vector3, _is_vehicle: bool = false, _requester: Node3D = null) -> Array[Vector3]:
	var start_grid = world_to_grid(start_world)
	var end_grid = world_to_grid(end_world)

	if not astar.region.has_point(start_grid) or not astar.region.has_point(end_grid):
		return []

	var path_grid = astar.get_id_path(start_grid, end_grid)
	var path_world: Array[Vector3] = []
	for p in path_grid:
		path_world.append(grid_to_world(p))

	# Basic Smoothing Pass
	return smooth_path(path_world, _requester)

func smooth_path(path: Array[Vector3], requester: Node3D = null) -> Array[Vector3]:
	if path.size() <= 2:
		return path

	var smoothed: Array[Vector3] = [path[0]]
	var current_idx = 0

	while current_idx < path.size() - 1:
		var furthest_visible = current_idx + 1
		for i in range(current_idx + 2, path.size()):
			if _has_clear_path(path[current_idx], path[i], requester):
				furthest_visible = i
			else:
				break
		smoothed.append(path[furthest_visible])
		current_idx = furthest_visible

	return smoothed

func _has_clear_path(a: Vector3, b: Vector3, requester: Node3D = null) -> bool:
	var space_state = get_world_3d().direct_space_state
	var start = a + Vector3(0, 0.5, 0)
	var end = b + Vector3(0, 0.5, 0)

	var dir = (end - start).normalized()
	var side = Vector3(-dir.z, 0, dir.x) * 0.4

	for offset in [Vector3.ZERO, side, -side]:
		var query = PhysicsRayQueryParameters3D.create(start + offset, end + offset)
		if requester:
			query.exclude = [requester]
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			return false
	return true
