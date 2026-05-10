extends CharacterBody3D

@onready var selection_visual = $SelectionVisual
@onready var push_area = $PushArea

@export var team = 0 # 0 for player, 1 for enemy
@export var health = 200.0
@export var capacity = 4

# Car-like movement properties
@export var max_speed = 10.0
@export var acceleration = 5.0
@export var friction = 2.0
@export var steer_speed = 3.0
@export var turn_radius = 2.0

var is_selected = false:
	set(value):
		is_selected = value
		if selection_visual:
			selection_visual.visible = value

var path: Array[Vector3] = []
var current_speed = 0.0
var steering = 0.0

func _ready():
	selection_visual.visible = is_selected
	global_position.y = 0

	# Setup collision based on team
	if team == 0:
		collision_layer = 2
		collision_mask = 1 | 4 # Ground/Obstacles | Team 1
	else:
		collision_layer = 4
		collision_mask = 1 | 2 # Ground/Obstacles | Team 0

	# Set color based on team
	var material = StandardMaterial3D.new()
	if team == 0:
		material.albedo_color = Color(0, 0.5, 1)
	else:
		material.albedo_color = Color(1, 0, 0)
	$MeshInstance3D.material_override = material

func _physics_process(delta):
	global_position.y = 0

	if health <= 0:
		queue_free()
		return

	_handle_car_movement(delta)
	_handle_soft_push(delta)

func _handle_soft_push(delta):
	var bodies = push_area.get_overlapping_bodies()
	var pushed_count = 0
	for body in bodies:
		if body != self and body.is_in_group("units") and body.team == team:
			var push_dir = (body.global_position - global_position)
			push_dir.y = 0
			var dist = push_dir.length()
			if dist < 0.1: continue # Avoid division by zero

			# Forceful push for teammates
			var force = (4.5 - dist) / 4.0
			body.global_position += push_dir.normalized() * force * 15.0 * delta
			pushed_count += 1

	# Apply resistance (slow down based on number of units being pushed)
	if pushed_count > 0:
		current_speed = move_toward(current_speed, max_speed * 0.4, acceleration * delta * pushed_count)

func _handle_car_movement(delta):
	if path.is_empty():
		current_speed = move_toward(current_speed, 0, friction * delta * 2.0)
		velocity = -transform.basis.z * current_speed
		move_and_slide()
		return

	var target = path[0]
	var to_target = (target - global_position)
	to_target.y = 0

	# Detect if we are approaching the final point
	var is_final_point = path.size() == 1
	var stop_dist = 2.0 if is_final_point else 1.0

	if to_target.length() < stop_dist:
		path.remove_at(0)
		if path.is_empty():
			return
		target = path[0]
		to_target = (target - global_position)
		to_target.y = 0
		is_final_point = path.size() == 1

	# Calculate steering angle
	var target_dir = to_target.normalized()
	var forward = -transform.basis.z
	var angle_to_target = forward.signed_angle_to(target_dir, Vector3.UP)

	# Simple steering logic
	steering = move_toward(steering, clamp(angle_to_target, -1.0, 1.0), steer_speed * delta)

	# Acceleration logic
	# Slow down for sharp turns
	var throttle = 1.0 - (abs(steering) * 0.5)

	# Braking logic: Slow down as we approach the final destination
	if is_final_point:
		var dist = to_target.length()
		if dist < 10.0:
			throttle *= (dist / 10.0)

	current_speed = move_toward(current_speed, max_speed * throttle, acceleration * delta)

	# Rotate the car based on speed and steering
	rotate_y(steering * current_speed * delta / turn_radius)

	velocity = -transform.basis.z * current_speed
	move_and_slide()

func move_to(target_pos: Vector3):
	var main = get_tree().current_scene
	if main and main.has_method("get_astar_path"):
		var new_path = main.get_astar_path(global_position, target_pos)

		if new_path.size() > 1:
			var first_point = new_path[0]
			var dist_to_first = (first_point - global_position)
			dist_to_first.y = 0
			if dist_to_first.length() < 1.0:
				new_path.remove_at(0)

		path = new_path

func take_damage(amount):
	health -= amount
