extends Area3D

@export var capture_speed = 10.0 # Percent per second per unit (max 30)
@export var capture_progress = 0.0 # -100 (Enemy) to 100 (Player)
@export var current_owner = -1 # -1: None, 0: Player, 1: Enemy

@onready var mesh = $MeshInstance3D
var progress_ui = null

func _ready():
	# Use deferred find to ensure UI is ready
	call_deferred("_setup_ui")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta):
	var units = get_overlapping_bodies()
	var player_count = 0
	var enemy_count = 0

	for body in units:
		if body.is_in_group("units"):
			if body.team == 0:
				player_count += 1
			else:
				enemy_count += 1

	if player_count > 0 and enemy_count == 0:
		capture_progress = move_toward(capture_progress, 100.0, delta * capture_speed * min(player_count, 3))
	elif enemy_count > 0 and player_count == 0:
		capture_progress = move_toward(capture_progress, -100.0, delta * capture_speed * min(enemy_count, 3))

	_update_visuals()

func _setup_ui():
	progress_ui = get_tree().current_scene.find_child("CaptureUI", true, false)

func _update_visuals():
	var mat = mesh.get_active_material(0)
	if capture_progress > 0:
		mat.albedo_color = Color(0, 0.5, 1).lerp(Color(1, 1, 1), 1.0 - (abs(capture_progress) / 100.0))
	elif capture_progress < 0:
		mat.albedo_color = Color(1, 0, 0).lerp(Color(1, 1, 1), 1.0 - (abs(capture_progress) / 100.0))
	else:
		mat.albedo_color = Color(1, 1, 1)

	if progress_ui:
		progress_ui.value = capture_progress

func _on_body_entered(body):
	pass

func _on_body_exited(body):
	pass
