# item_slot.gd
extends Panel

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel

var _icon_atlas: Texture2D = preload("res://assets/images/items/item_icons.png")
#var _icon_atlas: Texture2D = preload("res://assets/images/tilesets/fire_shader_.png")

var slot_index: int = -1
var item_id: String = ""
var count: int = 0  
	
func set_slot(id: String, amount: int) -> void:
	item_id = id
	count = amount
	if item_id == "":
		clear_slot()
		return
	var item = ItemRegistry.get_item(item_id)
	if item.is_empty():
		print("set_slot: registry lookup FAILED for ", item_id)
		return
	var atlas = AtlasTexture.new()
	atlas.atlas = _icon_atlas
	atlas.region = Rect2(item.icon_x, item.icon_y, 16, 16)
	icon.texture = atlas
	count_label.text = str(count) if count > 1 else ""
	count_label.visible = true
	
func clear_slot() -> void:
	item_id = ""
	count = 0
	icon.texture = null
	count_label.text = ""

func set_selected(selected: bool) -> void:
	if selected:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.2)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1, 1, 0, 1)  # yellow highlight
		add_theme_stylebox_override("panel", style)
	else:
		remove_theme_stylebox_override("panel")

func _get_drag_data(at_position: Vector2):
	if item_id == "":
		return null
	# Show a preview icon following the cursor
	var preview = TextureRect.new()
	preview.texture = icon.texture
	preview.custom_minimum_size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_drag_preview(preview)
	return { "item_id": item_id, "count": count, "slot_index": slot_index }
	
func _can_drop_data(at_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("slot_index") and data["slot_index"] != slot_index

func _drop_data(at_position: Vector2, data) -> void:
	get_tree().get_first_node_in_group("inventory_ui").move_slot(data["slot_index"], slot_index)
