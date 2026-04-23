extends CharacterBody3D

@onready var selection_visual = $SelectionVisual
@onready var shooting_visual = $ShootingVisual
@onready var attack_timer = $AttackTimer

@export var team = 0 # 0 for player, 1 for enemy
@export var health = 100.0
@export var attack_range = 10.0
@export var attack_damage = 10.0
@export var attack_rate = 1.0

var is_selected = false:
	set(value):
		is_selected = value
		if selection_visual:
			selection_visual.visible = value

var path: Array[Vector3] = []
var speed = 5.0
var stuck_timer = 0.0
var last_pos = Vector3.ZERO
var target_unit: CharacterBody3D = null

func _ready():
	selection_visual.visible = is_selected
	global_position.y = 0
	attack_timer.wait_time = 1.0 / attack_rate

	# Set color based on team
	var material = StandardMaterial3D.new()
	if team == 0:
		material.albedo_color = Color(0, 0.5, 1) # Blue for player
	else:
		material.albedo_color = Color(1, 0, 0) # Red for enemy
	$MeshInstance3D.material_override = material

func _physics_process(delta):
	global_position.y = 0

	if health <= 0:
		queue_free()
		return

	_handle_movement(delta)
	_handle_combat(delta)

func _handle_movement(delta):
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

func _handle_combat(delta):
	if not target_unit or not is_instance_valid(target_unit) or target_unit.health <= 0 or global_position.distance_to(target_unit.global_position) > attack_range:
		target_unit = _find_nearest_enemy()

	if target_unit and attack_timer.is_stopped():
		if _has_line_of_sight(target_unit):
			_shoot(target_unit)
			attack_timer.start()

func _find_nearest_enemy():
	var units = get_tree().get_nodes_in_group("units")
	var nearest = null
	var min_dist = attack_range

	for unit in units:
		if unit.team != team and unit.health > 0:
			var dist = global_position.distance_to(unit.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = unit
	return nearest

func _has_line_of_sight(target):
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), target.global_position + Vector3(0, 1, 0))
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	if result:
		return result.collider == target
	return false

func _shoot(target):
	target.take_damage(attack_damage)

	# Visual effect
	shooting_visual.look_at(target.global_position + Vector3(0, 1, 0))
	var dist = global_position.distance_to(target.global_position)
	shooting_visual.scale.z = dist
	shooting_visual.position = Vector3(0, 1, -dist/2.0)
	shooting_visual.visible = true
	await get_tree().create_timer(0.1).timeout
	shooting_visual.visible = false
	shooting_visual.position = Vector3.ZERO
	shooting_visual.scale = Vector3(0.1, 0.1, 1)

func take_damage(amount):
	health -= amount

func move_to(target_pos: Vector3):
	var main = get_tree().current_scene
	if main and main.has_method("get_astar_path"):
		var new_path = main.get_astar_path(global_position, target_pos)

		if new_path.size() > 1:
			var first_point = new_path[0]
			var dist_to_first = (first_point - global_position)
			dist_to_first.y = 0
			if dist_to_first.length() < 0.4:
				new_path.remove_at(0)

		path = new_path
