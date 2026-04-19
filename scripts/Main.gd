extends Node3D

var astar = AStarGrid2D.new()
var grid_size = Vector2i(200, 200)
var cell_size = 0.5
var offset = Vector2(-50, -50)

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

	# Mark obstacles as solid
	# We check the 'obstacles' group and children of the 'Obstacles' node for redundancy
	var obstacle_nodes = get_tree().get_nodes_in_group("obstacles")
	var obstacles_container = find_child("Obstacles", true, false)
	if obstacles_container:
		for child in obstacles_container.get_children():
			if not obstacle_nodes.has(child):
				obstacle_nodes.append(child)

	for obstacle in obstacle_nodes:
		var pos = obstacle.global_position
		var grid_pos = world_to_grid(pos)

		# Obstacles are 2x2x2. Cell size is 0.5, so 4x4 cells.
		# We mark a slightly larger area to prevent units (radius 0.4) from clipping.
		# Mark 5x5 cells (radius 1.25 units) to ensure clearance.
		for x in range(-2, 3):
			for y in range(-2, 3):
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

func get_astar_path(start_world: Vector3, end_world: Vector3) -> Array[Vector3]:
	var start_grid = world_to_grid(start_world)
	var end_grid = world_to_grid(end_world)

	if not astar.region.has_point(start_grid) or not astar.region.has_point(end_grid):
		return []

	var path_grid = astar.get_id_path(start_grid, end_grid)
	var path_world: Array[Vector3] = []
	for p in path_grid:
		path_world.append(grid_to_world(p))
	return path_world
