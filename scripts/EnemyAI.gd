extends Node

@export var update_interval = 2.0
var update_timer = 0.0

func _process(delta):
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_think()

func _think():
	var enemies = []
	var players = []
	var capture_point = null

	for node in get_tree().get_nodes_in_group("units"):
		if node.team == 1:
			enemies.append(node)
		else:
			players.append(node)

	var main = get_tree().current_scene
	var capt = main.find_child("CapturePoint", true, false)

	if enemies.is_empty():
		return

	# AI Logic
	# 1. If hill is not fully captured by us, move there
	if capt and capt.capture_progress > -100.0:
		_move_group(enemies, Vector3.ZERO)
	# 2. If hill is captured, seek and destroy players
	elif not players.is_empty():
		# Move towards the average position of players
		var avg_pos = Vector3.ZERO
		for p in players:
			avg_pos += p.global_position
		avg_pos /= players.size()
		_move_group(enemies, avg_pos)

func _move_group(units, target):
	var count = units.size()
	var side = ceil(sqrt(count))
	var offset_start = (side - 1) * 1.5 / 2.0
	for i in range(count):
		var x = i % int(side)
		var z = i / int(side)
		var offset = Vector3(x * 1.5 - offset_start, 0, z * 1.5 - offset_start)
		units[i].move_to(target + offset)
