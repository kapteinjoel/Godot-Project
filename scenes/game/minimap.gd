extends SubViewportContainer

@onready var minimap_tilemap: TileMap = $SubViewport/MiniMap
@onready var minimap_camera: Camera2D = $SubViewport/Camera2D
@onready var player_icon: Sprite2D = $SubViewport/Sprite2D

# Map your main game's Terrain enum values to your micro-tileset atlas coordinates
const TERRAIN_MAPPING = {
	0: Vector2i(0, 0),   # Terrain.GRASS
	9: Vector2i(1, 0),   # Terrain.MATTED_GRASS
	1: Vector2i(2, 0),   # Terrain.SAND
	17: Vector2i(3, 0),  # Terrain.WOOD_WALL
	2: Vector2i(4, 0)    # Terrain.WATER
}

const MINI_TILE_SIZE = 4
const HUD_MARGIN_RIGHT = 20
const HUD_MARGIN_TOP = 20 

# --- Toggle State Variables ---
var is_expanded: bool = false

# --- Explicitly Set Your Desired Pixels Here ---
# Tweak these numbers until the small map sits exactly where you want it!
const SMALL_MAP_SIZE = Vector2(200, 200)
var screen_size
var SMALL_MAP_POSITION 


const EXPANDED_MAP_SIZE = Vector2(450, 450)

func _ready() -> void:
	# Explicitly force the starting layout on boot
	size = SMALL_MAP_SIZE
	$SubViewport.size = SMALL_MAP_SIZE
	screen_size = get_viewport_rect().size
	SMALL_MAP_POSITION = Vector2(screen_size[0] - (SMALL_MAP_SIZE.x + HUD_MARGIN_RIGHT) , 20) 
	position = SMALL_MAP_POSITION
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_minimap"):
		toggle_map_state()

func toggle_map_state() -> void:
	is_expanded = !is_expanded
	
	if is_expanded:
		# 1. Scale up to expanded size
		size = EXPANDED_MAP_SIZE
		$SubViewport.size = EXPANDED_MAP_SIZE
		
		# 2. Force center layout using window viewport dimensions
		
		position = (screen_size / 2.0) - (size / 2.0)
	else:
		# 1. Snap back to your exact designated pixel size
		size = SMALL_MAP_SIZE
		$SubViewport.size = SMALL_MAP_SIZE
		
		# 2. Force it back to your exact designated pixel location
		position = SMALL_MAP_POSITION

func update_hud_position() -> void:
	var screen_size = get_viewport_rect().size
	
	# Change global_position to position
	position = Vector2(
		screen_size.x - size.x - HUD_MARGIN_RIGHT,
		HUD_MARGIN_TOP
	)

func update_tile(tile_pos: Vector2i, terrain_type: int) -> void:
	if TERRAIN_MAPPING.has(terrain_type):
		var atlas_coords = TERRAIN_MAPPING[terrain_type]
		minimap_tilemap.set_cell(0, tile_pos, 0, atlas_coords)
	elif terrain_type == -1:
		minimap_tilemap.set_cell(0, tile_pos, -1)

func track_player(player_tile_coords: Vector2i) -> void:
	var minimap_pixel_pos = Vector2(
		player_tile_coords.x * MINI_TILE_SIZE, 
		player_tile_coords.y * MINI_TILE_SIZE
	)
	minimap_camera.global_position = minimap_pixel_pos
	player_icon.global_position = minimap_pixel_pos
