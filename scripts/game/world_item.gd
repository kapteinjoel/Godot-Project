# world_item.gd
extends Node2D

var item_id: String = ""
var count: int = 1
var tile_pos: Vector2i

@onready var sprite := $Sprite2D

var _icon_atlas: Texture2D = preload("res://assets/images/items/item_icons.png")

func setup(id: String, amount: int = 1) -> void:
	item_id = id
	count = amount
	var item = ItemRegistry.get_item(id)
	if item.is_empty():
		return
	sprite.texture = _icon_atlas
	sprite.region_enabled = true
	sprite.region_rect = Rect2(item.icon_x, item.icon_y, 16, 16)
	sprite.offset = Vector2(-8, -8)

func _ready() -> void:
	$PickupArea.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		var leftover = body.pickup_item(item_id, count)
		if leftover == 0:
			queue_free()
		else:
			count = leftover  # inventory was full, leave remainder
