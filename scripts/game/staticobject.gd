extends Node2D

var tile_pos: Vector2i

@export var atlas_texture: Texture2D
@onready var sprite := $Sprite2D
@onready var stems := $Stems

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
	RIVER_ROCK_4
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
	OBJECT_TYPE.RIVER_ROCK_4: Rect2i(128, 64, 16, 16)
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
}

@export var object_type: OBJECT_TYPE:
	set(value):
		object_type = value
		_apply_object_type()

func _ready():
	sprite = $Sprite2D
	_apply_object_type()

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
		# Map LILY_1..LILY_8 → LILY_STEM_1..LILY_STEM_8
		var stem_type := (object_type + (OBJECT_TYPE.LILY_STEM_1 - OBJECT_TYPE.LILY_1)) as OBJECT_TYPE
		if OBJECT_REGIONS.has(stem_type):
			stems.region_rect = OBJECT_REGIONS[stem_type]
		if OBJECT_OFFSETS.has(stem_type):
			stems.offset = OBJECT_OFFSETS[stem_type]
		if OBJECT_Z_INDEX.has(stem_type):
			stems.z_index = OBJECT_Z_INDEX[stem_type]
