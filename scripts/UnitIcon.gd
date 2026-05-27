extends PanelContainer

@onready var icon_rect = $VBoxContainer/Icon
@onready var health_bar = $VBoxContainer/HealthBar

var linked_unit: Node3D

func setup(unit: Node3D):
	linked_unit = unit
	unit.health_changed.connect(_on_health_changed)
	unit.selection_changed.connect(_on_selection_changed)
	unit.tree_exiting.connect(queue_free)

	# Initial state
	_on_health_changed(unit.health, unit.max_health)
	_on_selection_changed(unit.is_selected)

	# Color the icon based on unit type or just blue for player
	icon_rect.modulate = Color(0, 0.5, 1)
	if "capacity" in unit: # Vehicle
		icon_rect.modulate = Color(0, 0.8, 1)

func _on_health_changed(current, max_h):
	health_bar.max_value = max_h
	health_bar.value = current

func _on_selection_changed(selected):
	var sb = StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(1, 1, 1, 0.2)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(1, 1, 1, 1)
	else:
		sb.bg_color = Color(0, 0, 0, 0.3)

	add_theme_stylebox_override("panel", sb)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Selection logic: in a real RTS, clicking the icon might select only that unit
		# For now, let's just make it select the unit
		for u in get_tree().get_nodes_in_group("units"):
			if u.team == 0:
				u.is_selected = (u == linked_unit)
