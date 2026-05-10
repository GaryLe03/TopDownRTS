extends Node3D

var static_astar = AStarGrid2D.new()
var dynamic_astar = AStarGrid2D.new()
var grid_size = Vector2i(800, 800)
var cell_size = 0.5
var offset = Vector2(-200, -200)

func _ready():
	# Wait for a frame to ensure all scene nodes are fully ready and placed
	await get_tree().process_frame
	setup_grid()

func setup_grid():
	for astar in [static_astar, dynamic_astar]:
		astar.region = Rect2i(0, 0, grid_size.x, grid_size.y)
		astar.cell_size = Vector2(cell_size, cell_size)
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
		astar.update()

	# Mark static obstacles as solid in both grids
	var obstacle_nodes = get_tree().get_nodes_in_group("obstacles")
	for obstacle in obstacle_nodes:
		var pos = obstacle.global_position
		var grid_pos = world_to_grid(pos)

		# Determine radius based on obstacle type (Building is larger)
		# Obstacle is 2x2 (radius 1). Building is 12x12 (radius 6).
		# We add 0.5 units padding (1 cell)
		var cell_radius = 3 # Default for small obstacles (1.5 units)
		if obstacle.name.begins_with("Building"):
			cell_radius = 14 # For buildings (7 units)

		for x in range(-cell_radius, cell_radius + 1):
			for y in range(-cell_radius, cell_radius + 1):
				var p = grid_pos + Vector2i(x, y)
				if static_astar.region.has_point(p):
					static_astar.set_point_solid(p, true)
					dynamic_astar.set_point_solid(p, true)

	static_astar.update()
	dynamic_astar.update()

var update_tick = 0.0

func _process(delta):
	update_tick += delta
	if update_tick >= 0.1:
		update_tick = 0.0
		_update_dynamic_grid()

var last_veh_positions = []

func _update_dynamic_grid():
	# Instead of full reset, we only clear previous vehicle spots
	for p in last_veh_positions:
		if dynamic_astar.region.has_point(p):
			dynamic_astar.set_point_solid(p, static_astar.is_point_solid(p))

	last_veh_positions.clear()

	# Mark vehicles as solid in dynamic grid
	for veh in get_tree().get_nodes_in_group("units"):
		if "capacity" in veh and is_instance_valid(veh): # Simple way to identify vehicle
			var pos = veh.global_position
			var grid_pos = world_to_grid(pos)
			# Vehicle is 3x6. Mark 7x13 area for clearance
			for x in range(-3, 4):
				for y in range(-6, 7):
					# Handle rotation - this is a simple approximation
					var p = grid_pos + Vector2i(x, y)
					if dynamic_astar.region.has_point(p):
						dynamic_astar.set_point_solid(p, true)
						last_veh_positions.append(p)

	dynamic_astar.update()

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

func get_astar_path(start_world: Vector3, end_world: Vector3, is_vehicle: bool = false, requester: Node3D = null) -> Array[Vector3]:
	var astar = static_astar if is_vehicle else dynamic_astar

	var start_grid = world_to_grid(start_world)
	var end_grid = world_to_grid(end_world)

	if not astar.region.has_point(start_grid) or not astar.region.has_point(end_grid):
		return []

	var path_grid = astar.get_id_path(start_grid, end_grid)
	var path_world: Array[Vector3] = []
	for p in path_grid:
		path_world.append(grid_to_world(p))

	return smooth_path(path_world, requester)

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
	# Cast ray slightly above ground
	var start = a + Vector3(0, 0.5, 0)
	var end = b + Vector3(0, 0.5, 0)

	# We use a sphere cast (via multiple rays or shape cast) to account for unit width
	# For simplicity, we use 3 rays (center, left, right)
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
