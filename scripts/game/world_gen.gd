extends Node2D

const RIVER_THRESHOLD = 0.2   # Lower = narrower rivers, raise for wider
const RIVER_BANK_THRESHOLD = 0.26  # Sandy bank just outside river
const RIVER_HALF_WIDTH = 4.5    # Changes river tile diameter
const RIVER_BANK_WIDTH = 1.5    # bank tiles on top of that
const MIN_TILE_WIDTH_FOR_ISLAND = 17 # The river must be at least this many tiles wide to get an island
const ISLAND_NOISE_THRESHOLD = 0.01  # Lower = bigger islands, Higher = smaller/fewer islands

@onready var tilemap: TileMap = $WorldTileMap
@onready var tilefollower: Sprite2D = $TileFollower
@onready var object_container = $Objects # Node to hold objects (i.e. trees, plants, pots etc.)
@onready var players_container = $Players
@onready var mob_manager = $MobManager

@onready var minimap =  get_tree().get_first_node_in_group("minimap")

@export var player: Node2D 
@export var chunk_size := 6 # Must be 6 idk why so leave it
@export var view_distance := 7 # How many chunks to render around the player
@export var tree: PackedScene = preload("res://scenes/game/worldgen/tree.tscn")
@export var plant: PackedScene = preload("res://scenes/game/worldgen/plant.tscn")
@export var placeable: PackedScene = preload("res://scenes/game/worldgen/staticobject.tscn")

var temperature := FastNoiseLite.new()
var moisture := FastNoiseLite.new()
var altitude := FastNoiseLite.new()
var river_noise: FastNoiseLite  # Primary river path noise
var river_warp: FastNoiseLite   # Domain warping for snaking effect
var original_cats: Array = []
var varieties = null
var random_type = null
var ts = null
var terrain = null
var object_spawn_rng = RandomNumberGenerator.new()
var use_changeset = true


var generated_chunks := {} # Stores already generated chunks
var chunk_containers = {} # Used to tie objects to their respective chunk
var dirty_chunks := {}  # tracks which chunks need saving
var chunks_with_saved_data := {}  # populated on world load
var chunks_requiring_direct_update: Dictionary = {}
var pending_terrain_updates: Array = []
var current_change_set = null
var active_change_sets: Array = []

# The tilemap layer for the player to edit tiles at
var players_layer_index := 9

# Used to store tiles changed by the player by their chunk
var changed_tiles_by_chunk : Dictionary = {}
#var reserved_tiles: Dictionary = {}

# Tilemap layers
enum Layers { STONE = -12, SAND = -11, GRASS = -10, UNDERWATER = -9, WATERSHADER = -8, WATER = -7, GROUND = -6, FLOOR = -5, FLOOR_DECOR = -4,  COLLISION = -3, OBJECTTILE = -2, MODIFIEDAREA = -1 }
# Tiles/Terrains used in chunk generation
enum LayersToUpdate { GROUND = -6, FLOOR = -5, COLLISION = -3 }

enum Terrain { 
	GRASS = 0, 
	SAND = 1, 
	WATER = 2, 
	DIRT = 3, 
	SNOW = 4, 
	HAUNT = 5, 
	PLAIN = 6, 
	STONE = 7, 
	AUTUMM = 8,
	MATTED_GRASS = 9,
	WATER_EDGE = 10,
	WATER_MASK = 11,
	OBJECT_TILE = 12,
	WATER_MEDIUM = 13,
	WOOD_FLOOR = 14,
	MODIFIED_AREA = 15,
	GROUND_PLACEHOLDER = 16,
	WOOD_WALL = 17
	}

# Decoration tiles that cannot be interacted with, used as an overlay
var DECORATIONS = {
	"forest_flower_white_1": Vector2i(17, 0),
	"forest_flower_white_2": Vector2i(18, 0),
	"forest_flower_white_3": Vector2i(19, 0),
	"forest_flower_white_4": Vector2i(20, 0),
	"forest_flower_white_5": Vector2i(21, 0),
	"bank_grass_1": Vector2i(22, 0),
	"bank_grass_2": Vector2i(23, 0),
	"bank_grass_3": Vector2i(24, 0),
	"bank_grass_4": Vector2i(25, 0),
	"bank_grass_5": Vector2i(26, 0),
	"forest_ground_grass_1": Vector2i(17, 1),
	"forest_ground_grass_2": Vector2i(18, 1),
	"forest_ground_grass_3": Vector2i(19, 1),
	"forest_ground_grass_4": Vector2i(20, 1),
	"forest_ground_grass_5": Vector2i(21, 1),
	"forest_flower_purple_1": Vector2i(17, 2),
	"forest_flower_purple_2": Vector2i(18, 2),
	"forest_flower_purple_3": Vector2i(19, 2),
	"forest_flower_purple_4": Vector2i(20, 2),
	"forest_flower_purple_5": Vector2i(21, 2),
	"forest_flower_yellow_1": Vector2i(17, 3),
	"forest_flower_yellow_2": Vector2i(18, 3),
	"forest_flower_yellow_3": Vector2i(19, 3),
	"forest_flower_yellow_4": Vector2i(20, 3),
	"forest_flower_yellow_5": Vector2i(21, 3),
	"forest_flower_red_1": Vector2i(17, 4),
	"forest_flower_red_2": Vector2i(18, 4),
	"forest_flower_red_3": Vector2i(19, 4),
	"forest_flower_red_4": Vector2i(20, 4),
	"forest_flower_red_5": Vector2i(21, 4),
}

var OBJECT_SETUP_FNS = {
	"CHEST_1": func(obj, data): obj.object_type = obj.OBJECT_TYPE.CHEST_1; obj.load_contents(data),
	"BARREL_1": func(obj, data): obj.object_type = obj.OBJECT_TYPE.BARREL_1,
}

var HOUSE_1 = [

	# --- Walls (COLLISION layer) ---
	# Top edge (y = 0)
	[Vector2i(0,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(1,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(2,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(3,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(4,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(5,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(6,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(7,0), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(8,0), Layers.COLLISION, Terrain.WOOD_WALL],
	# Left edge (x = 0, y = 1..4)
	[Vector2i(0,1), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(0,2), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(0,3), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(0,4), Layers.COLLISION, Terrain.WOOD_WALL],
	# Right edge (x = 8, y = 1..4)
	[Vector2i(8,1), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(8,2), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(8,3), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(8,4), Layers.COLLISION, Terrain.WOOD_WALL],
	# Bottom of main body (y = 5, x = 2..8) — x=1 is the doorway column so no wall here
	[Vector2i(2,5), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(3,5), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(4,5), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(5,5), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(6,5), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(7,5), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(8,5), Layers.COLLISION, Terrain.WOOD_WALL],
	[Vector2i(0,5), Layers.COLLISION, Terrain.WOOD_WALL],

	# --- Floor ---
	[Vector2i(1,1), Layers.FLOOR, Terrain.WOOD_FLOOR, "BARREL_1"],
	[Vector2i(2,1), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(3,1), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(4,1), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(5,1), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(6,1), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(7,1), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(1,2), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(2,2), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(3,2), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(4,2), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(5,2), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(6,2), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(7,2), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(1,3), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(2,3), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(3,3), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(4,3), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(5,3), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(6,3), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(7,3), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(1,4), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(2,4), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(3,4), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(4,4), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(5,4), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(6,4), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(7,4), Layers.FLOOR, Terrain.WOOD_FLOOR],
	[Vector2i(1,5), Layers.FLOOR, Terrain.WOOD_FLOOR],
]
func _ready() -> void:
	set_process(false)
	randomize()
	
	#ts = tilemap.tile_set
	#terrain = BetterTerrain.get_terrain(ts, Terrain.SAND)
	#original_cats = terrain.categories.duplicate()
	
	# Load in tiles changed by the player
	if Global.world_data.has("changed_tiles_by_chunk"):
		changed_tiles_by_chunk = Global.world_data.changed_tiles_by_chunk
	else:
		# If it's a new player joining, start with an empty dictionary
		# The Host will send the real data via RPC shortly after
		changed_tiles_by_chunk = {}
	
	# World gen settings
	object_spawn_rng.seed = Global.world_data.seed
	print("World is generating with seed: " + str(Global.world_data.seed))
	temperature.seed = int(Global.world_data.seed) # Load in the saved world seed
	temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperature.fractal_octaves = 5
	temperature.frequency = 1.0 / 5000
	
	moisture.seed = int(Global.world_data.seed) + 1
	moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moisture.fractal_octaves = 5
	moisture.frequency = 1.0 / 4500
	
	altitude.seed = int(Global.world_data.seed) + 2
	altitude.noise_type = FastNoiseLite.TYPE_SIMPLEX
	altitude.fractal_octaves = 5
	altitude.frequency = 1.0 / 1200
	
	river_noise = FastNoiseLite.new()
	river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	river_noise.seed = int(Global.world_data.seed) + 999
	river_noise.frequency = 0.003      # Low frequency = long, continuous rivers
	river_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	river_noise.fractal_octaves = 3
	
	river_warp = FastNoiseLite.new()
	river_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	river_warp.seed = int(Global.world_data.seed) + 1337
	river_warp.frequency = 0.002       # Higher = more winding/snaking
	
	load_saved_chunk_index() 
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		$SaveTimer.timeout.connect(_on_save_timer_timeout) # Start timer to save world data
		# Spawn the host (you)
		player = spawn_player(1)
		player.change_skin_color(Global.character_data.skin_color)
		mob_manager.set_process(true)
		set_process(true)
		
func _process(_delta: float) -> void:
	var center := get_player_tile_coords()
	var center_chunk := get_chunk_coords(center)
	
	load_chunks_around(center_chunk)
	unload_far_chunks(center_chunk)
	
	# Loop backward through active sets so we can safely remove them as they finish
	for i in range(active_change_sets.size() - 1, -1, -1):
		var change_set = active_change_sets[i]
		
		if BetterTerrain.is_terrain_changeset_ready(change_set):
			BetterTerrain.apply_terrain_changeset(change_set)
			active_change_sets.remove_at(i) # Clean up this specific thread tracker
	
	# Only clear and queue up new updates if ALL previous layer calculations are fully complete
	if active_change_sets.is_empty():
		_flush_terrain_updates()

func _enter_tree() -> void:
	$Players/MultiplayerSpawner.spawned.connect(_on_player_spawned)
	
func _input(event):
	if event.is_action_pressed("change_tile"):
		var hovered_tile = tilefollower.get_hovered_tile_coords()
		change_tile_at_location(hovered_tile, players_layer_index, Terrain.WOOD_WALL)
		
func _on_save_timer_timeout() -> void:
	for chunk_coords in dirty_chunks.keys():
		save_chunk_changes(chunk_coords)
	dirty_chunks.clear()
	
func change_tile_at_location(tile_coords: Vector2i, layer_index: int, terrain_type: int):
	var chunk_coords = get_chunk_coords(tile_coords)
	if not changed_tiles_by_chunk.has(chunk_coords):
		changed_tiles_by_chunk[chunk_coords] = {}

	# Create a unique key combining position and layer
	var unique_key = str(tile_coords.x, ",", tile_coords.y, "_", layer_index)

	# Save the data under this unique key
	changed_tiles_by_chunk[chunk_coords][unique_key] = {
		"terrain_type": terrain_type,
		"layer_index": layer_index,
		"x": tile_coords.x, # Save raw ints so we don't have to parse strings on load
		"y": tile_coords.y
	}
	
	var modified_layer_id = Layers.MODIFIEDAREA
	var modified_terrain_id = Terrain.MODIFIED_AREA
	var modified_key = str(tile_coords.x, ",", tile_coords.y, "_", modified_layer_id)
	
	changed_tiles_by_chunk[chunk_coords][modified_key] = {
		"terrain_type": modified_terrain_id,
		"layer_index": modified_layer_id,
		"x": tile_coords.x,
		"y": tile_coords.y
	}
	# ---------------------------------------------------------------------------------
	var object_key = str(tile_coords.x, ",", tile_coords.y, "_object")
	if changed_tiles_by_chunk[chunk_coords].has(object_key):
		changed_tiles_by_chunk[chunk_coords].erase(object_key)
		
	dirty_chunks[chunk_coords] = true  # mark dirty, don't write yet
	chunks_requiring_direct_update[chunk_coords] = true
	if generated_chunks.has(chunk_coords):
		generated_chunks.erase(chunk_coords)
	if chunk_containers.has(chunk_coords):
		var container = chunk_containers[chunk_coords]
		container.queue_free()
		chunk_containers.erase(chunk_coords)
		clear_chunk_object_tiles(chunk_coords)
	
func get_player_tile_coords() -> Vector2i:
	return tilemap.local_to_map(player.global_position)
	
func get_chunk_file_path(chunk_coords: Vector2i) -> String:
	var world_name_lower = Global.world_data.name.strip_edges().replace(" ", "_").to_lower()
	return "user://worlds/" + world_name_lower + "/chunks/" + str(chunk_coords.x) + "_" + str(chunk_coords.y) + ".json"
	
func _flush_terrain_updates():
	if pending_terrain_updates.is_empty():
		return
		
	var merged: Rect2i = pending_terrain_updates[0]
	for rect in pending_terrain_updates:
		merged = merged.merge(rect)
	pending_terrain_updates.clear()
	
	for layer_index in LayersToUpdate.values():
		var cells_to_update: Dictionary = {}
		
		# Godot's range() and Rect2i.end are exclusive, so we use <= to hit the final border tile
		var x_start = merged.position.x
		var x_end = merged.end.x
		var y_start = merged.position.y
		var y_end = merged.end.y
		
		for x in range(x_start, x_end + 1):
			for y in range(y_start, y_end + 1):
				var pos = Vector2i(x, y)
				var cell_type = BetterTerrain.get_cell(tilemap, layer_index, pos)
				
				# --- THE FIX ---
				# Only include the tile in the changeset if it actually contains a terrain type.
				# If it's -1, skipping it prevents BetterTerrain from trying to autotile into the void.
				if cell_type != -1:
					cells_to_update[pos] = cell_type
		
		# Only create a changeset if we actually found tiles to update in this layer
		if not cells_to_update.is_empty():
			var new_set = BetterTerrain.create_terrain_changeset(tilemap, layer_index, cells_to_update)
			if new_set != null:
				active_change_sets.append(new_set)

func cancel_pending_updates_in_area(area: Rect2i):
	# BetterTerrain changesets don't expose their internal rects easily, 
	# but we can clear our tracker array if we are completely rewriting the region.
	# If multiple chunks are processing, it's safest to let the thread finish 
	# but instantly override its results on the main thread, or clear the queue.
	
	# Clear out our un-flushed rects queue so stale frames don't build
	for i in range(pending_terrain_updates.size() - 1, -1, -1):
		if area.intersects(pending_terrain_updates[i]):
			pending_terrain_updates.remove_at(i)		
			
func load_saved_chunk_index() -> void:
	var world_name_lower = Global.world_data.name.strip_edges().replace(" ", "_").to_lower()
	var chunks_dir = "user://worlds/" + world_name_lower + "/chunks/"
	var dir = DirAccess.open(chunks_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var parts = file_name.trim_suffix(".json").split("_")
			if parts.size() == 2:
				var coords = Vector2i(int(parts[0]), int(parts[1]))
				chunks_with_saved_data[coords] = true
		file_name = dir.get_next()
	dir.list_dir_end()
	
func save_object_to_chunk(tile_pos: Vector2i, object_id: String, object_data: Dictionary = {}):
	var chunk_coords = get_chunk_coords(tile_pos)
	if not changed_tiles_by_chunk.has(chunk_coords):
		changed_tiles_by_chunk[chunk_coords] = {}
	var object_key = str(tile_pos.x, ",", tile_pos.y, "_object")
	changed_tiles_by_chunk[chunk_coords][object_key] = {
		"type": "object",
		"object_id": object_id,
		"object_data": object_data,
		"x": tile_pos.x,
		"y": tile_pos.y
	}
	dirty_chunks[chunk_coords] = true

func save_chunk_changes(chunk_coords: Vector2i) -> void:
	if not changed_tiles_by_chunk.has(chunk_coords):
		return
	chunks_with_saved_data[chunk_coords] = true
	var file_path = get_chunk_file_path(chunk_coords)
	var temp_path = file_path + ".tmp"

	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())

	# Your keys are already strings ("X,Y_Layer"), so we can copy directly
	var serializable = changed_tiles_by_chunk[chunk_coords]

	var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		print("Error: Could not write chunk file: ", temp_path)
		return
	temp_file.store_string(JSON.stringify(serializable, "\t"))
	temp_file.close()

	DirAccess.rename_absolute(temp_path, file_path)

func load_chunk_changes(chunk_coords: Vector2i) -> void:
	if changed_tiles_by_chunk.has(chunk_coords):
		return
	if not chunks_with_saved_data.has(chunk_coords):
		return  # no file exists, skip entirely
	var file_path = get_chunk_file_path(chunk_coords)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		return
		
	# Keep the string keys intact so layer data doesn't clobber each other
	changed_tiles_by_chunk[chunk_coords] = parsed

func str_to_vec2i(s: String) -> Vector2i:
	var clean = s.strip_edges().trim_prefix("(").trim_suffix(")")
	var parts = clean.split(",")
	return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))

func get_chunk_coords(tile_coords: Vector2i) -> Vector2i:
	return Vector2i(
		floor(float(tile_coords.x) / chunk_size),
		floor(float(tile_coords.y) / chunk_size)
	)
	
func load_chunks_around(center_chunk: Vector2i):
	# Iterate in a spiral pattern from the center outwards
	for r in range(view_distance + 1):
		for i in range(-r, r + 1):
			# Top and bottom edges of the spiral ring
			var top_chunk = center_chunk + Vector2i(i, -r)
			if not generated_chunks.has(top_chunk):
				#generate_chunk(top_chunk)
				generate_chunk_new(top_chunk)
				generated_chunks[top_chunk] = true
				return # <- Exit after generating one chunk

			var bottom_chunk = center_chunk + Vector2i(i, r)
			if not generated_chunks.has(bottom_chunk):
				#generate_chunk(bottom_chunk)
				generate_chunk_new(bottom_chunk)
				generated_chunks[bottom_chunk] = true
				return # <- Exit after generating one chunk

			# Left and right edges of the spiral ring
			var left_chunk = center_chunk + Vector2i(-r, i)
			if not generated_chunks.has(left_chunk):
				#generate_chunk(left_chunk)
				generate_chunk_new(left_chunk)
				generated_chunks[left_chunk] = true
				return # <- Exit after generating one chunk
				
			var right_chunk = center_chunk + Vector2i(r, i)
			if not generated_chunks.has(right_chunk):
				#generate_chunk(right_chunk)
				generate_chunk_new(right_chunk)
				generated_chunks[right_chunk] = true
				return # <- Exit after generating one chunk

func unload_far_chunks(center_chunk: Vector2i):
	var keys_to_remove := []
	for chunk in generated_chunks.keys():
		if abs(chunk.x - center_chunk.x) > view_distance + 1 or abs(chunk.y - center_chunk.y) > view_distance + 1:
			clear_chunk(chunk)
			keys_to_remove.append(chunk)
	for chunk in keys_to_remove:
		generated_chunks.erase(chunk)
		changed_tiles_by_chunk.erase(chunk)

func clear_chunk(chunk_coords: Vector2i):
	var start_x = chunk_coords.x * chunk_size
	var start_y = chunk_coords.y * chunk_size
	var area = Rect2i(start_x, start_y, chunk_size, chunk_size)
	for x in range(area.position.x, area.position.x + area.size.x):
		for y in range(area.position.y, area.position.y + area.size.y):
			for layer in Layers.keys():
				tilemap.set_cell(Layers[layer], Vector2i(x, y), -1)
	if chunk_containers.has(chunk_coords):
		var container = chunk_containers[chunk_coords]
		container.queue_free() # Deletes the container and all objects inside it
		chunk_containers.erase(chunk_coords) # Remove from dictionary

func clear_chunk_object_tiles(chunk_coords: Vector2i):
	var chunk_origin = chunk_coords * chunk_size
	for x in range(chunk_size):
		for y in range(chunk_size):
			var tile_pos = chunk_origin + Vector2i(x, y)
			if BetterTerrain.get_cell(tilemap, Layers.OBJECTTILE, tile_pos) == Terrain.OBJECT_TILE:
				tilemap.erase_cell(Layers.OBJECTTILE, tile_pos)

func get_or_create_chunk_container(chunk_coords: Vector2i):
	# If container already exists get it and skip the rest
	if chunk_containers.has(chunk_coords):
		return chunk_containers[chunk_coords]
	
	# Create a new object container for this chunk if it didn't already exist
	var container = Node2D.new()
	container.name = "Chunk_%d_%d" % [chunk_coords.x, chunk_coords.y]
	container.y_sort_enabled = true 
	
	object_container.add_child(container)
	chunk_containers[chunk_coords] = container
	return container

func generate_chunk_new(chunk_coords: Vector2i):
	if chunks_with_saved_data.has(chunk_coords):
		load_chunk_changes(chunk_coords)
	var start_x = chunk_coords.x * chunk_size
	var start_y = chunk_coords.y * chunk_size
	for x in range(start_x, start_x + chunk_size):
		for y in range(start_y, start_y + chunk_size):
			var tile_pos = Vector2i(x, y)
			var temp = 2 * (abs(temperature.get_noise_2d(x, y)))
			var moist = 2 * (abs(moisture.get_noise_2d(x, y)))
			var alt = 2 * (abs(altitude.get_noise_2d(x, y)))
			var tile_seed = Global.world_data.seed + (tile_pos.x * 374761393) + (tile_pos.y * 668265263)
			object_spawn_rng.seed = tile_seed
			# === OCEAN ===
			if alt < 0.2:
				generate_ocean(tile_pos, chunk_coords, alt)
			# === RIVER — checked before beach so it can cut through to ocean ===
			elif is_river_tile(x, y, alt):
				generate_river(tile_pos, chunk_coords)
			elif is_river_bank(x, y, alt):
				generate_river_bank(tile_pos, chunk_coords)
			# === BEACH ===
			elif between(alt, 0.2, 0.25):
				#BetterTerrain.set_terrain(ts, Terrain.SAND, terrain.name, terrain.color, terrain.type, [])
				BetterTerrain.set_cell(tilemap, Layers.SAND , tile_pos, Terrain.SAND)
				BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.GROUND_PLACEHOLDER)
			# === LAND ZONE ===
			elif between(alt, 0.25, 0.8):
				var is_plains = between(moist, 0, 0.4) and between(temp, 0.2, 0.6)
				var is_autumn = between(moist, 0.4, 0.9) and (temp > 0.6)
				var is_desert = temp > 0.7 and moist < 0.4
				if is_plains:
					pass
					#BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.PLAIN)
				elif is_autumn:
					pass
					#BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.AUTUMM)
				elif is_desert:
					pass
					#BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.STONE)
				else:
					generate_forest(tile_pos, chunk_coords)
			# === HIGH ALTITUDE FOREST ===
			else:
				generate_forest(tile_pos, chunk_coords)
	# Update tiles changed by the player
	var changed_tiles_in_this_chunk: Dictionary = changed_tiles_by_chunk.get(chunk_coords, {})
	for key in changed_tiles_in_this_chunk.keys():
		var tile_data = changed_tiles_in_this_chunk[key]
		
		# Skip object entries — handled separately below
		if tile_data.get("type", "") == "object":
			continue
		
		var tile_pos = Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
		var terrain_type = int(tile_data.get("terrain_type", Terrain.GRASS))
		var saved_layer_index = int(tile_data.get("layer_index", players_layer_index))
		BetterTerrain.set_cell(tilemap, saved_layer_index, tile_pos, terrain_type)
		
	if chunks_requiring_direct_update.has(chunk_coords):
		var update_area = Rect2i(start_x - 1, start_y - 1, chunk_size + 2, chunk_size + 2)
		for layer in LayersToUpdate.keys():
			BetterTerrain.update_terrain_area.call_deferred(tilemap, Layers[layer], update_area)
		
		# Clean up the tracker for this chunk since it's now updated
		chunks_requiring_direct_update.erase(chunk_coords)
	else:
		# Use your optimized background thread changeset
		pending_terrain_updates.append(Rect2i(start_x - 1, start_y - 1, chunk_size + 2, chunk_size + 2))
	
	# load in placed objects
	for key in changed_tiles_in_this_chunk.keys():
		var tile_data = changed_tiles_in_this_chunk[key]
		if tile_data.get("type", "") == "object":
			var tile_pos = Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
			var instance = spawn_object(tile_pos, chunk_coords, placeable, true)
			if instance != null:
				var object_id = tile_data.get("object_id", "")
				var object_data = tile_data.get("object_data", {})
				if OBJECT_SETUP_FNS.has(object_id):
					OBJECT_SETUP_FNS[object_id].call(instance, object_data)
	# After All generation is done reload past mobs
	get_node("MobManager").load_mobs_for_chunk(chunk_coords)
		
func between(val, start, end):
	if start <= val and val < end:
		return true

func generate_ocean(tile_pos, chunk_coords: Vector2i, alt):
	BetterTerrain.set_cell(tilemap, Layers.SAND, tile_pos, Terrain.SAND)
	BetterTerrain.set_cell(tilemap, Layers.WATERSHADER, tile_pos, Terrain.WATER_MASK)
	BetterTerrain.set_cell(tilemap, Layers.WATER, tile_pos, Terrain.WATER)
	BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.WATER_EDGE)
	var depth = 1.0 - (alt / 0.2)
	if depth > 0.6:
		BetterTerrain.set_cell(tilemap, Layers.WATER, tile_pos, Terrain.WATER_MEDIUM)
	else:
		BetterTerrain.set_cell(tilemap, Layers.WATER, tile_pos, Terrain.WATER)
	
func generate_river_bank(tile_pos, chunk_coords: Vector2i):
	BetterTerrain.set_cell(tilemap, Layers.SAND, tile_pos, Terrain.SAND)
	BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.GROUND_PLACEHOLDER)

	var river_dist = get_tiles_from_river_center(tile_pos.x, tile_pos.y)
	var bank_edge_threshold = RIVER_HALF_WIDTH + 3.0

	# --- Rocks ---
	var rock_noise = altitude.get_noise_2d(tile_pos.x * 15.0, tile_pos.y * 15.0)
	var in_rock_clump = between(rock_noise, 0.1, 0.18) or between(rock_noise, 0.5, 0.58)
	if in_rock_clump and river_dist <= bank_edge_threshold:
		var rock = spawn_object(tile_pos, chunk_coords, placeable)
		if rock != null:
			var rock_types = [
				rock.OBJECT_TYPE.RIVER_ROCK_1,
				rock.OBJECT_TYPE.RIVER_ROCK_2,
				rock.OBJECT_TYPE.RIVER_ROCK_3,
				rock.OBJECT_TYPE.RIVER_ROCK_4,
			]
			rock.object_type = rock_types[object_spawn_rng.randi() % rock_types.size()]
			return

	# --- Grass ---
	var grass_noise = altitude.get_noise_2d(tile_pos.x * 20.0 + 500.0, tile_pos.y * 20.0 + 500.0)
	var in_grass_clump = between(grass_noise, 0.05, 0.10)
	if in_grass_clump:
		varieties = ["bank_grass_1", "bank_grass_2", "bank_grass_3", "bank_grass_4", "bank_grass_5"]
		tilemap.set_cell(Layers.FLOOR_DECOR, tile_pos, 0, DECORATIONS[varieties[object_spawn_rng.randi() % varieties.size()]])
	
func generate_river(tile_pos, chunk_coords: Vector2i):
	BetterTerrain.set_cell(tilemap, Layers.SAND, tile_pos, Terrain.SAND)
	BetterTerrain.set_cell(tilemap, Layers.WATERSHADER, tile_pos, Terrain.WATER_MASK)
	BetterTerrain.set_cell(tilemap, Layers.WATER, tile_pos, Terrain.WATER)
	BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.WATER_EDGE)
	var river_dist = get_tiles_from_river_center(tile_pos.x, tile_pos.y)
	if river_dist > RIVER_HALF_WIDTH - 2.5:
		return
	# Noise just decides if we're in a clump zone or not
	var lily_noise = altitude.get_noise_2d(tile_pos.x * 20.0, tile_pos.y * 20.0)
	var in_clump = between(lily_noise, 0.0, 0.04) or between(lily_noise, 0.6, 0.64)
	if not in_clump:
		return
	# Type is randomised per tile within the clump
	var lily = spawn_object(tile_pos, chunk_coords, placeable)
	if lily != null:
		var lily_types = [lily.OBJECT_TYPE.LILY_1, lily.OBJECT_TYPE.LILY_2, lily.OBJECT_TYPE.LILY_3, lily.OBJECT_TYPE.LILY_4, lily.OBJECT_TYPE.LILY_5, lily.OBJECT_TYPE.LILY_6, lily.OBJECT_TYPE.LILY_7, lily.OBJECT_TYPE.LILY_8]
		lily.object_type = lily_types[object_spawn_rng.randi() % lily_types.size()]
	
func generate_forest(tile_pos, chunk_coords: Vector2i):
	var detail_noise = altitude.get_noise_2d(tile_pos.x * 15.0, tile_pos.y * 15.0)
	var secondary_detail_noise = altitude.get_noise_2d(tile_pos.x * 50.0, tile_pos.y * 50.0)
	var density = altitude.get_noise_2d(tile_pos.x * 2.0, tile_pos.y * 2.0)
	
	var roll = tile_hash(tile_pos, 2)
	var variety_roll = tile_hash(tile_pos, 3)
		
	if detail_noise < -0.6 and density < -0.3: # PONDS
		BetterTerrain.set_cell(tilemap, Layers.SAND, tile_pos, Terrain.SAND)
		BetterTerrain.set_cell(tilemap, Layers.WATERSHADER, tile_pos, Terrain.WATER_MASK)
		BetterTerrain.set_cell(tilemap, Layers.WATER, tile_pos, Terrain.WATER)
		BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.WATER_EDGE)

	elif between(detail_noise, -1.0, -0.5) and density < -0.25: # SAND / POND BORDERS
		BetterTerrain.set_cell(tilemap, Layers.SAND, tile_pos, Terrain.SAND)
		BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.GROUND_PLACEHOLDER)
		if between(detail_noise, -0.7, -0.57):
			if between(roll, 0.2, 0.9):
				var new_plant = spawn_object(tile_pos, chunk_coords, plant)
				if new_plant != null:
					varieties = ["forest_pond_reed_1", "forest_pond_reed_2", "forest_pond_reed_3"]
					new_plant.set_plant_type(varieties[int(variety_roll * varieties.size())])
		elif between(detail_noise, -0.54, -0.52):
			if roll < 0.5:
				var new_plant = spawn_object(tile_pos, chunk_coords, plant)
				if new_plant != null:
					varieties = ["forest_plant_1", "forest_plant_2", "forest_plant_3", "forest_plant_4", "forest_plant_5"]
					new_plant.set_plant_type(varieties[int(variety_roll * varieties.size())])
		elif between(detail_noise, -0.52, -0.5):
			varieties = ["forest_ground_grass_1", "forest_ground_grass_2", "forest_ground_grass_3", "forest_ground_grass_4", "forest_ground_grass_5"]
			tilemap.set_cell(Layers.FLOOR_DECOR, tile_pos, 0, DECORATIONS[varieties[int(variety_roll * varieties.size())]])
			if roll < 0.3:
				var new_plant = spawn_object(tile_pos, chunk_coords, plant)
				if new_plant != null:
					varieties = ["forest_plant_1", "forest_plant_2", "forest_plant_3", "forest_plant_4", "forest_plant_5"]
					new_plant.set_plant_type(varieties[int(tile_hash(tile_pos, 4) * varieties.size())])

	elif between(detail_noise, 0.1, 0.3): # MATTED GRASS
		BetterTerrain.set_cell(tilemap, Layers.GRASS, tile_pos, Terrain.MATTED_GRASS)
		BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.GROUND_PLACEHOLDER)
		if between(roll, 0.5, 0.8):
			var new_plant = spawn_object(tile_pos, chunk_coords, plant)
			if new_plant != null:
				varieties = ["forest_plant_1", "forest_plant_2", "forest_plant_3", "forest_plant_4", "forest_plant_5"]
				new_plant.set_plant_type(varieties[int(variety_roll * varieties.size())])
		elif between(roll, 0.9, 0.95) and not is_suppressed_by_nearby_tree(tile_pos, 3):
			var new_tree = spawn_object(tile_pos, chunk_coords, tree)
			if new_tree != null:
				new_tree.player = player
				new_tree.set_tree_type(new_tree.TREE_TYPE.PINE_LARGE_1)
		elif roll >= 0.95 and not is_suppressed_by_nearby_tree(tile_pos, 3):
			var new_tree = spawn_object(tile_pos, chunk_coords, tree)
			if new_tree != null:
				new_tree.player = player
				new_tree.set_tree_type(new_tree.TREE_TYPE.PINE_LARGE_2)

	elif between(detail_noise, 0.6, 0.7): # STONE MICRO BIOME
		BetterTerrain.set_cell(tilemap, Layers.STONE, tile_pos, Terrain.STONE)
		BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.GROUND_PLACEHOLDER)
		if between(detail_noise, 0.6, 0.63):
			varieties = ["forest_ground_grass_1", "forest_ground_grass_2", "forest_ground_grass_3", "forest_ground_grass_4", "forest_ground_grass_5"]
			tilemap.set_cell(Layers.FLOOR_DECOR, tile_pos, 0, DECORATIONS[varieties[int(variety_roll * varieties.size())]])
		if tile_hash(tile_pos, 5) > 0.95:
			var container = spawn_object(tile_pos, chunk_coords, placeable)
			if container != null:
				var container_types = [container.OBJECT_TYPE.BARREL_1, container.OBJECT_TYPE.CRATE_1]
				container.object_type = container_types[int(tile_hash(tile_pos, 6) * container_types.size())]

	else: # FOREST
		BetterTerrain.set_cell(tilemap, Layers.GRASS, tile_pos, Terrain.MATTED_GRASS)
		BetterTerrain.set_cell(tilemap, Layers.GROUND, tile_pos, Terrain.GROUND_PLACEHOLDER)
		BetterTerrain.set_cell(tilemap, Layers.FLOOR, tile_pos, Terrain.GRASS)
		
		# DECORATION FLOWERS
		if between(secondary_detail_noise, 0.0, 0.05):
			varieties = ["forest_flower_white_1", "forest_flower_white_2", "forest_flower_white_3", "forest_flower_white_4", "forest_flower_white_5"]
			tilemap.set_cell(Layers.FLOOR_DECOR, tile_pos, 0, DECORATIONS[varieties[int(variety_roll * varieties.size())]])
		if between(secondary_detail_noise, 0.2, 0.2075):
			varieties = ["forest_flower_yellow_1", "forest_flower_yellow_2", "forest_flower_yellow_3", "forest_flower_yellow_4", "forest_flower_yellow_5"]
			tilemap.set_cell(Layers.FLOOR_DECOR, tile_pos, 0, DECORATIONS[varieties[int(tile_hash(tile_pos, 7) * varieties.size())]])
		if between(secondary_detail_noise, 0.4, 0.4075):
			varieties = ["forest_flower_red_1", "forest_flower_red_2", "forest_flower_red_3", "forest_flower_red_4", "forest_flower_red_5"]
			tilemap.set_cell(Layers.FLOOR_DECOR, tile_pos, 0, DECORATIONS[varieties[int(tile_hash(tile_pos, 8) * varieties.size())]])
		if between(secondary_detail_noise, 0.6, 0.6075):
			varieties = ["forest_flower_purple_1", "forest_flower_purple_2", "forest_flower_purple_3", "forest_flower_purple_4", "forest_flower_purple_5"]
			tilemap.set_cell(Layers.FLOOR_DECOR, tile_pos, 0, DECORATIONS[varieties[int(tile_hash(tile_pos, 9) * varieties.size())]])
			
		if between(roll, 0.5, 0.8):
			var new_plant = spawn_object(tile_pos, chunk_coords, plant)
			if new_plant != null:
				varieties = ["forest_plant_1", "forest_plant_2", "forest_plant_3", "forest_plant_4", "forest_plant_5"]
				new_plant.set_plant_type(varieties[int(variety_roll * varieties.size())])
		elif wants_to_be_tree(tile_pos) and not is_suppressed_by_nearby_tree(tile_pos, 3):
			if between(roll, 0.8, 0.9):
				var new_tree = spawn_object(tile_pos, chunk_coords, tree)
				if new_tree != null:
					new_tree.player = player
					new_tree.set_tree_type(new_tree.TREE_TYPE.OAK_LARGE_1)
			elif roll >= 0.9:
				var new_tree = spawn_object(tile_pos, chunk_coords, tree)
				if new_tree != null:
					new_tree.player = player
					new_tree.set_tree_type(new_tree.TREE_TYPE.OAK_LARGE_2)
					
		if roll < 0.005 and between(detail_noise, -0.1, 0.1):
			if stamp_house(tile_pos, HOUSE_1):
				return
					
func get_river_value(x: int, y: int) -> float:
	var warp_strength = 30.0
	var wx = x + river_warp.get_noise_2d(x, y) * warp_strength
	var wy = y + river_warp.get_noise_2d(x + 500, y + 500) * warp_strength
	return abs(river_noise.get_noise_2d(wx, wy))
	
func is_river_tile(x: int, y: int, alt: float) -> bool:
	if alt < 0.2:
		return false
	# Sample neighbours to estimate the local gradient magnitude
	var center = get_river_value(x, y)
	var dx = (get_river_value(x + 1, y) - get_river_value(x - 1, y)) * 0.5
	var dy = (get_river_value(x, y + 1) - get_river_value(x, y - 1)) * 0.5
	var gradient = sqrt(dx * dx + dy * dy)
	# Normalise: distance-to-centerline in tiles = value / gradient
	# Clamp gradient so we don't divide by near-zero in flat noise areas
	var tiles_from_center = center / max(gradient, 0.008)
	return tiles_from_center < RIVER_HALF_WIDTH

func is_river_bank(x: int, y: int, alt: float) -> bool:
	if alt < 0.2:
		return false
	var center = get_river_value(x, y)
	var dx = (get_river_value(x + 1, y) - get_river_value(x - 1, y)) * 0.5
	var dy = (get_river_value(x, y + 1) - get_river_value(x, y - 1)) * 0.5
	var gradient = sqrt(dx * dx + dy * dy)
	var tiles_from_center = center / max(gradient, 0.008)
	return tiles_from_center >= RIVER_HALF_WIDTH and tiles_from_center < (RIVER_HALF_WIDTH + RIVER_BANK_WIDTH)

func get_tiles_from_river_center(x: int, y: int) -> float:
	var center = get_river_value(x, y)
	var dx = (get_river_value(x + 1, y) - get_river_value(x - 1, y)) * 0.5
	var dy = (get_river_value(x, y + 1) - get_river_value(x, y - 1)) * 0.5
	var gradient = sqrt(dx * dx + dy * dy)
	return center / max(gradient, 0.008)
	
func spawn_object(tile_pos: Vector2i, chunk_coords: Vector2i, scene_to_spawn: PackedScene, ignore_modified: bool = false):
	if BetterTerrain.get_cell(tilemap, Layers.OBJECTTILE, tile_pos) == Terrain.OBJECT_TILE:
		return null
	
	if not ignore_modified:
		var modified_key = str(tile_pos.x, ",", tile_pos.y, "_", Layers.MODIFIEDAREA)
		if changed_tiles_by_chunk.has(chunk_coords):
			if changed_tiles_by_chunk[chunk_coords].has(modified_key):
				return null

	var container = get_or_create_chunk_container(chunk_coords)
	var instance = scene_to_spawn.instantiate()
	
	instance.position = tilemap.map_to_local(tile_pos)
	instance.tile_pos = tile_pos
	container.add_child(instance)
	
	BetterTerrain.set_cell(tilemap, Layers.OBJECTTILE, tile_pos, Terrain.OBJECT_TILE)
	
	return instance

func stamp_house(origin: Vector2i, blueprint: Array):

	if blueprint.is_empty():
		return false
	var first_entry = blueprint[0]
	var first_tile_pos = origin + first_entry[0]
	var first_layer = first_entry[1]
	var first_chunk_coords = get_chunk_coords(first_tile_pos)
	var first_tile_key = str(first_tile_pos.x, ",", first_tile_pos.y, "_", first_layer)
	if changed_tiles_by_chunk.has(first_chunk_coords):
		if changed_tiles_by_chunk[first_chunk_coords].has(first_tile_key):
			return false
	print("Stamping house at origin: ", origin, " first tile: ", first_tile_pos, " chunk: ", first_chunk_coords)
	var affected_chunks = {}
	affected_chunks[first_chunk_coords] = true

	for entry in blueprint:
		var tile_pos = origin + entry[0]
		var layer = entry[1]
		var dterrain = entry[2]
		var setup_fn = entry[3] if entry.size() > 3 else null
		var chunk_coords = get_chunk_coords(tile_pos)
		if not changed_tiles_by_chunk.has(chunk_coords):
			changed_tiles_by_chunk[chunk_coords] = {}
		var unique_key = str(tile_pos.x, ",", tile_pos.y, "_", layer)
		changed_tiles_by_chunk[chunk_coords][unique_key] = {
			"terrain_type": dterrain,
			"layer_index": layer,
			"x": tile_pos.x,
			"y": tile_pos.y
		}
		var modified_key = str(tile_pos.x, ",", tile_pos.y, "_", Layers.MODIFIEDAREA)
		changed_tiles_by_chunk[chunk_coords][modified_key] = {
			"terrain_type": Terrain.MODIFIED_AREA,
			"layer_index": Layers.MODIFIEDAREA,
			"x": tile_pos.x,
			"y": tile_pos.y
		}
		dirty_chunks[chunk_coords] = true
		affected_chunks[chunk_coords] = true
		if setup_fn != null:
			save_object_to_chunk(tile_pos, setup_fn)

	# Reload each affected chunk exactly once
	for chunk_coords in affected_chunks:
		chunks_requiring_direct_update[chunk_coords] = true
		var start_x = chunk_coords.x * chunk_size
		var start_y = chunk_coords.y * chunk_size
		var chunk_box = Rect2i(start_x, start_y, chunk_size, chunk_size)
		
		# Cancel any queued up flushes waiting for this area
		cancel_pending_updates_in_area(chunk_box)
		if generated_chunks.has(chunk_coords):
			generated_chunks.erase(chunk_coords)
			if chunk_containers.has(chunk_coords):
				chunk_containers[chunk_coords].queue_free()
				chunk_containers.erase(chunk_coords)
				clear_chunk_object_tiles(chunk_coords)
	return true
	
func wants_to_be_tree(tile_pos: Vector2i) -> bool:
	return tile_hash(tile_pos) > 0.8

func tree_priority(tile_pos: Vector2i) -> float:
	return tile_hash(tile_pos, 1)

func tile_hash(tile_pos: Vector2i, salt: int = 0) -> float:
	var h = int(Global.world_data.seed) + (tile_pos.x * 374761393) + (tile_pos.y * 668265263) + salt
	h = (h ^ (h >> 16)) * 0x45d9f3b
	h = (h ^ (h >> 16)) * 0x45d9f3b
	h = h ^ (h >> 16)
	return (h & 0x7fffffff) / float(0x7fffffff) 
	
func is_suppressed_by_nearby_tree(tile_pos: Vector2i, min_distance: int) -> bool:
	if not wants_to_be_tree(tile_pos):
		return true
	var my_priority = tree_priority(tile_pos)
	for dx in range(-min_distance, min_distance + 1):
		for dy in range(-min_distance, min_distance + 1):
			if dx == 0 and dy == 0:
				continue
			var neighbor = tile_pos + Vector2i(dx, dy)
			if wants_to_be_tree(neighbor):
				var neighbor_priority = tree_priority(neighbor)
				if neighbor_priority > my_priority:
					return true
	return false

# MULTIPLAYER STUFF
@rpc("authority", "call_remote", "reliable")
func sync_world_state(encoded_data: String):
	var json = JSON.new()
	var error = json.parse(encoded_data)
	if error == OK:
		# Update the global data with what the host sent
		Global.world_data.changed_tiles_by_chunk = json.get_data()
		# Refresh the chunks the player is currently seeing
		generated_chunks.clear() 
		print("World state synced from host!")

func _on_peer_connected(id: int):
	# ONLY the host spawns players. The Spawner replicates it to others.
	if multiplayer.is_server():
		spawn_player(id)
		
		# Send world data to the specific peer
		var data_to_send = JSON.stringify(Global.world_data.changed_tiles_by_chunk)
		sync_world_state.rpc_id(id, data_to_send)

func spawn_player(id: int):
	# This now only runs on the Host/Server
	var player_scene = preload("res://scenes/game/player.tscn")
	var new_player = player_scene.instantiate()
	new_player.name = str(id) 
	new_player.set_multiplayer_authority(id)
	players_container.add_child(new_player)
	return new_player
	
func _on_peer_disconnected(id: int):
	if players_container.has_node(str(id)):
		players_container.get_node(str(id)).queue_free()

func _on_player_spawned(node: Node):
	# This runs on EVERYONE whenever a new player node is replicated
	var id = node.name.to_int()
	node.set_multiplayer_authority(id)
	print('test')
	# This is where the client finally assigns THEIR own player variable
	if id == multiplayer.get_unique_id():
		player = node
		print("Client: My local player is now assigned!")
		set_process(true)
		mob_manager.set_process(true)
