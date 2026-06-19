# item_slot.gd
extends Panel

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel

var _icon_atlas: Texture2D = preload("res://assets/images/items/item_icons.png")

func set_slot(item_id: String, count: int) -> void:
	if item_id == "":
		clear_slot()
		return
	var item = ItemRegistry.get_item(item_id)
	if item.is_empty():
		return
	var atlas = AtlasTexture.new()
	atlas.atlas = _icon_atlas
	atlas.region = Rect2(item.icon_x, item.icon_y, 16, 16)
	icon.texture = atlas
	count_label.text = str(count) if count > 1 else ""
	count_label.visible = true

func clear_slot() -> void:
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
