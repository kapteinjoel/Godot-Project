# world_item.gd
extends Node2D

var item_id: String = ""
var count: int = 1
var tile_pos: Vector2i
signal picked_up(tile_pos: Vector2i)
var can_pickup := false

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
	# Prevent immediate re-pickup after dropping
	await get_tree().create_timer(0.8).timeout
	can_pickup = true


func _on_body_entered(body: Node2D) -> void:
	if not can_pickup:
		return
	if body.is_in_group("player") and body.is_multiplayer_authority():
		var leftover = body.pickup_item(item_id, count)
		if leftover == 0:
			picked_up.emit(tile_pos)
			queue_free()
		else:
			count = leftover
			var world_gen = get_tree().get_first_node_in_group("world_gen")
			if world_gen:
				world_gen.save_world_item_to_chunk(tile_pos, item_id, count)
