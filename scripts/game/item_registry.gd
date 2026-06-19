extends Node

var _items: Dictionary = {}
var _icon_atlas: Texture2D  # One spritesheet for all item icons

func _ready() -> void:
	_icon_atlas = load("res://assets/images/items/item_icons.png")
	_load_all_items()

func _load_all_items() -> void:
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	if file == null:
		push_error("ItemRegistry: could not open items.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		push_error("ItemRegistry: failed to parse items.json")
		return
	for id in parsed.keys():
		_items[id] = parsed[id]
		_items[id]["id"] = id
	print("ItemRegistry loaded ", _items.size(), " items")

func get_item(id: String) -> Dictionary:
	if not _items.has(id):
		push_warning("ItemRegistry: unknown item id: " + id)
		return {}
	return _items[id]

func get_icon(id: String) -> AtlasTexture:
	var item = get_item(id)
	if item.is_empty():
		return null
	var atlas = AtlasTexture.new()
	atlas.atlas = _icon_atlas
	atlas.region = Rect2(item.icon_x, item.icon_y, 16, 16)
	return atlas
