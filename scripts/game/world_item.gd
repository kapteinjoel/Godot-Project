# world_item.gd
extends CharacterBody2D

var item_id: String = ""
var count: int = 1
var tile_pos: Vector2i
signal picked_up(tile_pos: Vector2i)
var can_pickup := false

const THROW_SPEED := 70.0
const DECELERATION := 80.0
var _was_moving: bool = false

@onready var sprite := $Sprite2D
var _icon_atlas: Texture2D = preload("res://assets/images/items/item_icons.png")

func setup(id: String, amount: int = 1, throw_dir: Vector2 = Vector2.ZERO) -> void:
	item_id = id
	count = amount
	var item = ItemRegistry.get_item(id)
	if item.is_empty():
		return
	sprite.texture = _icon_atlas
	sprite.region_enabled = true
	sprite.region_rect = Rect2(item.icon_x, item.icon_y, 16, 16)
	sprite.offset = Vector2(-8, -8)
	if throw_dir != Vector2.ZERO:
		velocity = throw_dir.normalized() * THROW_SPEED

func _ready() -> void:
	add_to_group("world_items")
	$PickupArea.body_entered.connect(_on_body_entered)
	await get_tree().create_timer(0.8).timeout
	can_pickup = true
	_try_merge_nearby()
	for body in $PickupArea.get_overlapping_bodies():
		_on_body_entered(body)

func _physics_process(delta: float) -> void:
	if velocity.length() > 1.0:
		_was_moving = true
		velocity = velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
		move_and_slide()
	else:
		if _was_moving:
			_was_moving = false
			_update_save_position()
			_try_merge_nearby()
		velocity = Vector2.ZERO
		
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

func _update_save_position() -> void:
	var new_tile_pos = Vector2i(floori(global_position.x / 16.0), floori(global_position.y / 16.0))
	if new_tile_pos == tile_pos:
		return  # landed in same tile, no update needed
	var world_gen = get_tree().get_first_node_in_group("world_gen")
	if world_gen:
		world_gen.remove_world_item_from_chunk(tile_pos)
		tile_pos = new_tile_pos
		world_gen.save_world_item_to_chunk(tile_pos, item_id, count)

func _try_merge_nearby() -> void:
	var item_data = ItemRegistry.get_item(item_id)
	if item_data.is_empty():
		return
	var max_stack: int = item_data["max_stack_size"]
	if count >= max_stack:
		return
	var world_gen = get_tree().get_first_node_in_group("world_gen")
	for other in get_tree().get_nodes_in_group("world_items"):
		if other == self or not is_instance_valid(other):
			continue
		if other.item_id != item_id:
			continue
		if global_position.distance_to(other.global_position) > 15.0:
			continue
		# Absorb as much as fits
		var space = max_stack - count
		var take = min(space, other.count)
		count += take
		other.count -= take
		if world_gen:
			world_gen.save_world_item_to_chunk(tile_pos, item_id, count)
			if other.count <= 0:
				world_gen.remove_world_item_from_chunk(other.tile_pos)
				other.queue_free()
			else:
				world_gen.save_world_item_to_chunk(other.tile_pos, other.item_id, other.count)
		if count >= max_stack:
			break
