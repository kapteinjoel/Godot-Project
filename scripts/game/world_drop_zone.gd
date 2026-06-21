extends Control

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary or not data.has("slot_index"):
		return false
	# Don't catch drops that are over the inventory panel
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and inventory_ui.inventory_panel.visible:
		var panel = inventory_ui.inventory_panel
		var panel_rect = Rect2(panel.global_position, panel.size)
		if panel_rect.has_point(get_global_mouse_position()):
			return false
	return true

func _drop_data(at_position: Vector2, data) -> void:
	get_tree().get_first_node_in_group("inventory_ui").drop_to_world(data["slot_index"])
