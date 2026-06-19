extends Node2D

var tile_pos: Vector2i

@export var atlas_texture: Texture2D
@onready var sprite := $Sprite2D
@onready var stems := $Stems
#@onready var solid_collision_shape := $CollisionShape2D

# Nodes for collision handling
@onready var click_area := $ClickArea
@onready var solid_body_collision := $SolidCollisionShape

var inventory: Array = []

enum OBJECT_TYPE {
	ROCK_1,
	BARREL_1,
	CRATE_1,
	LILY_1,
	LILY_2,
	LILY_3,
	LILY_4,
	LILY_5,
	LILY_6,
	LILY_7,
	LILY_8,
	LILY_STEM_1,
	LILY_STEM_2,
	LILY_STEM_3,
	LILY_STEM_4,
	LILY_STEM_5,
	LILY_STEM_6,
	LILY_STEM_7,
	LILY_STEM_8,
	RIVER_ROCK_1,
	RIVER_ROCK_2,
	RIVER_ROCK_3,
	RIVER_ROCK_4,
	WOOD_DOOR_CLOSED,
	WOOD_DOOR_OPEN
}

const OBJECT_REGIONS := {
	OBJECT_TYPE.ROCK_1: Rect2i(17, 2, 30, 28),
	OBJECT_TYPE.BARREL_1: Rect2i(80, 80, 16, 16),
	OBJECT_TYPE.CRATE_1: Rect2i(96, 80, 16, 16),
	OBJECT_TYPE.LILY_1: Rect2i(64, 16, 16, 16),
	OBJECT_TYPE.LILY_2: Rect2i(80, 16, 16, 16),
	OBJECT_TYPE.LILY_3: Rect2i(96, 16, 16, 16),
	OBJECT_TYPE.LILY_4: Rect2i(112, 16, 16, 16),
	OBJECT_TYPE.LILY_5: Rect2i(128, 16, 16, 16),
	OBJECT_TYPE.LILY_6: Rect2i(144, 16, 16, 16),
	OBJECT_TYPE.LILY_7: Rect2i(160, 16, 16, 16),
	OBJECT_TYPE.LILY_8: Rect2i(176, 16, 16, 16),
	OBJECT_TYPE.LILY_STEM_1: Rect2i(64, 32, 16, 32),
	OBJECT_TYPE.LILY_STEM_2: Rect2i(80, 32, 16, 32),
	OBJECT_TYPE.LILY_STEM_3: Rect2i(96, 32, 16, 32),
	OBJECT_TYPE.LILY_STEM_4: Rect2i(112, 32, 16, 32),
	OBJECT_TYPE.LILY_STEM_5: Rect2i(128, 32, 16, 32),
	OBJECT_TYPE.LILY_STEM_6: Rect2i(144, 32, 16, 32),
	OBJECT_TYPE.LILY_STEM_7: Rect2i(160, 32, 16, 32),
	OBJECT_TYPE.LILY_STEM_8: Rect2i(176, 32, 16, 32),
	OBJECT_TYPE.RIVER_ROCK_1: Rect2i(80, 64, 16, 16),
	OBJECT_TYPE.RIVER_ROCK_2: Rect2i(96, 64, 16, 16),
	OBJECT_TYPE.RIVER_ROCK_3: Rect2i(112, 64, 16, 16),
	OBJECT_TYPE.RIVER_ROCK_4: Rect2i(128, 64, 16, 16),
	OBJECT_TYPE.WOOD_DOOR_CLOSED: Rect2i(192, 16, 16, 32),
	OBJECT_TYPE.WOOD_DOOR_OPEN: Rect2i(208, 16, 16, 32)
}

const OBJECT_OFFSETS := {
	OBJECT_TYPE.ROCK_1: Vector2(-8, -8),
	OBJECT_TYPE.CRATE_1: Vector2(-8, -8),
	OBJECT_TYPE.BARREL_1: Vector2(-8, -8),
	OBJECT_TYPE.LILY_1: Vector2(-8, -8),
	OBJECT_TYPE.LILY_2: Vector2(-8, -8),
	OBJECT_TYPE.LILY_3: Vector2(-8, -8),
	OBJECT_TYPE.LILY_4: Vector2(-8, -8),
	OBJECT_TYPE.LILY_5: Vector2(-8, -8),
	OBJECT_TYPE.LILY_6: Vector2(-8, -8),
	OBJECT_TYPE.LILY_7: Vector2(-8, -8),
	OBJECT_TYPE.LILY_8: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_1: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_2: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_3: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_4: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_5: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_6: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_7: Vector2(-8, -8),
	OBJECT_TYPE.LILY_STEM_8: Vector2(-8, -8),
	OBJECT_TYPE.RIVER_ROCK_1: Vector2(-8, -8),
	OBJECT_TYPE.RIVER_ROCK_2: Vector2(-8, -8),
	OBJECT_TYPE.RIVER_ROCK_3: Vector2(-8, -8),
	OBJECT_TYPE.RIVER_ROCK_4: Vector2(-8, -8),
	OBJECT_TYPE.WOOD_DOOR_CLOSED: Vector2(-8, -24),
	OBJECT_TYPE.WOOD_DOOR_OPEN: Vector2(-8, -24),
}

const OBJECT_Z_INDEX := {
	OBJECT_TYPE.ROCK_1: 0,
	OBJECT_TYPE.CRATE_1: 0,
	OBJECT_TYPE.BARREL_1: 0,
	OBJECT_TYPE.LILY_1: -1,
	OBJECT_TYPE.LILY_2: -1,
	OBJECT_TYPE.LILY_3: -1,
	OBJECT_TYPE.LILY_4: -1,
	OBJECT_TYPE.LILY_5: -1,
	OBJECT_TYPE.LILY_6: -1,
	OBJECT_TYPE.LILY_7: -1,
	OBJECT_TYPE.LILY_8: -1,
	OBJECT_TYPE.LILY_STEM_1: -5,
	OBJECT_TYPE.LILY_STEM_2: -5,
	OBJECT_TYPE.LILY_STEM_3: -5,
	OBJECT_TYPE.LILY_STEM_4: -5,
	OBJECT_TYPE.LILY_STEM_5: -5,
	OBJECT_TYPE.LILY_STEM_6: -5,
	OBJECT_TYPE.LILY_STEM_7: -5,
	OBJECT_TYPE.LILY_STEM_8: -5,
	OBJECT_TYPE.RIVER_ROCK_1: -1,
	OBJECT_TYPE.RIVER_ROCK_2: -1,
	OBJECT_TYPE.RIVER_ROCK_3: -1,
	OBJECT_TYPE.RIVER_ROCK_4: -1,
	OBJECT_TYPE.WOOD_DOOR_CLOSED: 0,
}

@export var object_type: OBJECT_TYPE:
	set(value):
		object_type = value
		_apply_object_type()

func _ready():
	sprite = $Sprite2D
	_apply_object_type()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("right_click"):
		# Only process for doors
		if object_type != OBJECT_TYPE.WOOD_DOOR_CLOSED and object_type != OBJECT_TYPE.WOOD_DOOR_OPEN:
			return
			
		if is_mouse_over_collision():
			toggle_door()
			get_viewport().set_input_as_handled()

func is_mouse_over_collision() -> bool:
	if not is_instance_valid(click_area):
		return false
		
	# 1. Get the direct, true world physics state
	var space_state := get_world_2d().direct_space_state
	if not space_state:
		return false
		
	# 2. Configure a point-intersection query exactly where the mouse is pointing
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true  # Detect our ClickArea
	query.collide_with_bodies = false # Ignore player/solid walls
	
	# 3. Fire the query into the physics database
	var results := space_state.intersect_point(query)
	
	# 4. Check if our personal ClickArea was one of the shapes hit
	for result in results:
		if result.has("collider") and result["collider"] == click_area:
			return true
			
	return false

func toggle_door() -> void:
	if object_type == OBJECT_TYPE.WOOD_DOOR_CLOSED:
		object_type = OBJECT_TYPE.WOOD_DOOR_OPEN
	elif object_type == OBJECT_TYPE.WOOD_DOOR_OPEN:
		object_type = OBJECT_TYPE.WOOD_DOOR_CLOSED
		
	# 1. Update visual sprite region textures
	_apply_object_type()
	
	# 2. Update physical solid blocking behavior
	_update_solid_blocking()

func _update_solid_blocking() -> void:
	if not is_instance_valid(solid_body_collision):
		return

	# 1. Determine if this object type should completely bypass physics
	var is_lily := object_type >= OBJECT_TYPE.LILY_1 and object_type <= OBJECT_TYPE.LILY_8
	var is_lily_stem := object_type >= OBJECT_TYPE.LILY_STEM_1 and object_type <= OBJECT_TYPE.LILY_STEM_8
	var is_river_rock := object_type >= OBJECT_TYPE.RIVER_ROCK_1 and object_type <= OBJECT_TYPE.RIVER_ROCK_4
	
	# If it's a lily, stem, or river rock, always disable collision
	if is_lily or is_lily_stem or is_river_rock:
		solid_body_collision.set_deferred("disabled", true)
		if is_instance_valid(click_area):
			# Optional: Disable click area too if you can't interact with them
			for child in click_area.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					child.set_deferred("disabled", true)
		return

	# 2. Otherwise, fall back to your standard door logic
	# If the door is OPEN, disabled = true (player walks through)
	# If the door is CLOSED, disabled = false (blocks player)
	var is_door_open := (object_type == OBJECT_TYPE.WOOD_DOOR_OPEN)
	solid_body_collision.set_deferred("disabled", is_door_open)

func _apply_object_type():	
	sprite.texture = atlas_texture
	stems.texture = atlas_texture
	sprite.region_enabled = true
	stems.region_enabled = true
	if OBJECT_REGIONS.has(object_type):
		sprite.region_rect = OBJECT_REGIONS[object_type]
	if OBJECT_OFFSETS.has(object_type):
		sprite.offset = OBJECT_OFFSETS[object_type]
	if OBJECT_Z_INDEX.has(object_type):
		z_index = OBJECT_Z_INDEX[object_type]

		
	# Apply stems only for lily types
	var is_lily := object_type >= OBJECT_TYPE.LILY_1 and object_type <= OBJECT_TYPE.LILY_8
	stems.visible = is_lily
	if is_lily:
		var stem_type := (object_type + (OBJECT_TYPE.LILY_STEM_1 - OBJECT_TYPE.LILY_1)) as OBJECT_TYPE
		if OBJECT_REGIONS.has(stem_type):
			stems.region_rect = OBJECT_REGIONS[stem_type]
		if OBJECT_OFFSETS.has(stem_type):
			stems.offset = OBJECT_OFFSETS[stem_type]
		if OBJECT_Z_INDEX.has(stem_type):
			stems.z_index = OBJECT_Z_INDEX[stem_type]
	_update_solid_blocking() 
func load_data(data: Dictionary):
	if data.is_empty():
		return
	if data.has("items"):
		inventory = data["items"]

func get_data() -> Dictionary:
	return {
		"items": inventory
	}
