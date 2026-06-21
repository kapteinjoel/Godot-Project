extends CharacterBody2D

const RUN_BOB_OFFSETS = [0.0, 1.0, 0.0, -1.0]
const MAX_ANIMATION_TICKS = 120

@export var speed := 100

@onready var eye_sprite: Sprite2D = $PlayerBody/Eyes
@onready var head_sprite: Sprite2D = $PlayerBody/Head
@onready var torso_sprite: Sprite2D = $PlayerBody/Torso
@onready var hand_sprite: Sprite2D = $PlayerBody/Hands
@onready var hair_sprite: Sprite2D = $PlayerBody/Hair
@onready var shirt_sprite: Sprite2D = $PlayerBody/Shirt
@onready var leg_sprite: Sprite2D = $PlayerBody/Legs
@onready var feet_sprite: Sprite2D = $PlayerBody/Feet

@onready var eye_dart_timer: Timer = $EyeDartTimer
@onready var run_animation_timer = $RunAnimationTimer
@onready var run_animation_timer_legs = $RunAnimationTimerVertical
@export var base_animation_interval = 0.1

@onready var body := $PlayerBody
@onready var reflection := $PlayerReflection/PlayerBody2

var inventory: Array = []  # [{ "item_id": "WOOD_LOG", "count": 5 }, ...]
var inventory_size = 30
signal inventory_changed(new_inventory: Array)

# --- Animation Variables ---
enum RunDir { LEFT, RIGHT, UP, DOWN }
@export var current_run_dir: RunDir = RunDir.RIGHT

# An array to hold the keys for the run animation frames in order
const RUN_FRAMES_RIGHT = [
	"default_run1_right",
	"default_run1_right", 
	"default_run2_right",  
	"default_run3_right",
]

const RUN_FRAMES_LEFT = [
	"default_run1_left",
	"default_run1_left", 
	"default_run2_left",  
	"default_run3_left",
]

const RUN_FRAMES_DOWN = [
	"default_run1_down",
	"default_run1_down", 
	"default_run2_down",  
	"default_run2_down",
]

const LEG_FRAMES_DOWN = [
	"default_down_running1",
	"default_down_running1",
	"default_down_running2",
	"default_down_running2"
]

const HAND_FRAMES_DOWN = [
	"default_hand_run_down1",
	"default_hand_run_down1",
	"default_hand_run_down1",
	"default_hand_run_down2",
	"default_hand_run_down2",
	"default_hand_run_down2"
]

const SHIRT_FRAMES_DOWN = [
	"default_shirt_run_down1",
	"default_shirt_run_down1",
	"default_shirt_run_down1",
	"default_shirt_run_down2",
	"default_shirt_run_down2",
	"default_shirt_run_down2",
]

# This variable will track which frame we are on (e.g., 0, 1, 2, 3)
var current_run_frame = 0
var current_leg_frame = 0

const EYE_REGIONS = {
	"look_left": Rect2(22, 2, 6, 2),
	"look_right": Rect2(22, 8, 6, 2),
}

const BODY_REGIONS = {
	"default_down": Rect2(25, 8, 12, 4),
	"default_up": Rect2(22, 2, 6, 2),
	"default_left": Rect2(8, 8, 12, 4),
	"default_right": Rect2(42, 8, 12, 4),
	"default_shirt_run_down1": Rect2(25, 16, 12, 4),
	"default_shirt_run_down2": Rect2(25, 24, 12, 4),
}

const HAND_REGIONS = {
	"default_down": Rect2(25, 13, 12, 3),
	"default_up": Rect2(22, 2, 6, 2),
	"default_left": Rect2(8, 13, 12, 3),
	"default_right": Rect2(42, 13, 12, 3),
	"default_hand_run_down1": Rect2(25, 18, 12, 5),
	"default_hand_run_down2": Rect2(25, 25, 12, 5),
}

const LEG_REGIONS = {
	"default_down": Rect2(12, 20, 6, 3),
	"default_up": Rect2(22, 2, 6, 2),
	"default_left": Rect2(4, 20, 6, 3),
	"default_right": Rect2(20, 20, 6, 3),
	"default_down_running1": Rect2(12, 25, 6, 3),
	"default_down_running2": Rect2(12, 30, 6, 3),
}

const HEAD_REGIONS = {
	"default_down": Rect2(41, 7, 10, 9),
	"default_up": Rect2(22, 2, 6, 2),
	"default_left": Rect2(23, 7, 12, 9),
	"default_right": Rect2(57, 7, 12, 9),
}

const FEET_REGIONS = {
	"default_down": Rect2(12, 13, 8, 3),
	"default_up": Rect2(22, 2, 6, 2),
	"default_left": Rect2(2, 13, 8, 3),
	"default_right": Rect2(22, 13, 8, 3),
	"default_run1_left": Rect2(164, 11, 10, 7),
	"default_run2_left": Rect2(154, 11, 8, 7),
	"default_run3_left": Rect2(144, 11, 6, 7),
	"default_run1_right": Rect2(112, 11, 10, 7),
	"default_run2_right": Rect2(124, 11, 8, 7),
	"default_run3_right": Rect2(136, 11, 6, 7),
	"default_run1_down": Rect2(178, 13, 8, 3),
	"default_run2_down": Rect2(191, 13, 8, 3),
	"default_run3_down": Rect2(178, 13, 8, 3),
}

var eye_directions: Array

func _ready():
	eye_sprite.region_enabled = true
	eye_directions = EYE_REGIONS.keys()
	
	eye_dart_timer.timeout.connect(_on_eye_dart_timer_timeout)
	run_animation_timer.timeout.connect(_on_animation_timer_timeout)

	
	if Global.character_data.has("inventory_size"):
		inventory_size = int(Global.character_data["inventory_size"])
	inventory.resize(inventory_size)
	for i in range(inventory_size):
		inventory[i] = { "item_id": "", "count": 0 }
	# Load saved inventory over the top
	if Global.character_data.has("inventory") and Global.character_data["inventory"] is Array:
		var saved = Global.character_data["inventory"]
		for i in range(min(saved.size(), inventory_size)):
			if saved[i] is Dictionary and saved[i].has("item_id"):
				inventory[i] = {
					"item_id": saved[i].get("item_id", ""),
					"count": int(saved[i].get("count", 0))
				}
	inventory_changed.emit(inventory)
	if Global.character_data.has("skin_color"):
		change_skin_color(Color(Global.character_data.skin_color))
		print(Global.character_data.skin_color)
	if Global.character_data.has("hair_color"):
		change_hair_color(Color(Global.character_data.hair_color))
		print(Global.character_data.hair_color)
	if Global.character_data.has("eye_color"):
		change_eye_color(Color(Global.character_data.eye_color))
		print(Global.character_data.eye_color)
	
	_on_eye_dart_timer_timeout()
	
func dict_to_color(d) -> Color:
	if d is Color:
		return d  # already a Color, no conversion needed
	return Color(d["r"], d["g"], d["b"], d.get("a", 1.0))

func save_inventory() -> void:
	Global.character_data["inventory"] = inventory
	Global.character_data["inventory_size"] = inventory_size
	var char_name = Global.character_data["name"].strip_edges().replace(" ", "_").to_lower()
	var file_path = "user://characters/" + char_name + ".json"
	var temp_path = file_path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save inventory for: " + char_name)
		return
	file.store_string(JSON.stringify(Global.character_data, "  "))
	file.close()
	
	DirAccess.rename_absolute(temp_path, file_path)

func _process(_delta):
	if not is_multiplayer_authority():
		$Camera2D.enabled = false
		return

	var mouse_position = get_global_mouse_position()
	var to_mouse = mouse_position - self.global_position
	var diagonal_threshold = 0.75

	# --- Determine new direction ---
	var new_dir = current_run_dir
	if to_mouse.y < -abs(to_mouse.x) * diagonal_threshold:
		new_dir = RunDir.UP
	elif to_mouse.y > abs(to_mouse.x) * diagonal_threshold:
		new_dir = RunDir.DOWN
	elif to_mouse.x < -abs(to_mouse.y) * diagonal_threshold:
		new_dir = RunDir.LEFT
	elif to_mouse.x > abs(to_mouse.y) * diagonal_threshold:
		new_dir = RunDir.RIGHT

	# --- Reset animation on direction change ---
	if new_dir != current_run_dir:
		current_run_dir = new_dir
		current_run_frame = 0
		run_animation_timer.stop()
		# FORCE an immediate sprite region update so it doesn't show old frames
		_apply_direction_sprites() 
		_apply_animation_frame() 

	# --- Apply static base sprites for current direction ---
	_apply_direction_sprites()

	# --- Handle animation ---
	if velocity.length() > 0:
		var speed_ratio = velocity.length() / speed
		run_animation_timer.wait_time = base_animation_interval / speed_ratio
		if run_animation_timer.is_stopped():
			run_animation_timer.start()
			_apply_animation_frame() # Ensure it looks right the moment we start moving
	else:
		run_animation_timer.stop()
		current_run_frame = 0
		_apply_idle_sprites()

	_sync_reflection()

func _apply_direction_sprites() -> void:
	match current_run_dir:
		RunDir.DOWN:
			# shirt and hand are handled by _apply_animation_frame / _apply_idle_sprites
			head_sprite.region_rect = HEAD_REGIONS["default_down"]
		RunDir.RIGHT:
			shirt_sprite.region_rect = BODY_REGIONS["default_right"]
			hand_sprite.region_rect = HAND_REGIONS["default_right"]
			head_sprite.region_rect = HEAD_REGIONS["default_right"]
			leg_sprite.region_rect = LEG_REGIONS["default_right"]
		RunDir.LEFT:
			shirt_sprite.region_rect = BODY_REGIONS["default_left"]
			hand_sprite.region_rect = HAND_REGIONS["default_left"]
			head_sprite.region_rect = HEAD_REGIONS["default_left"]
			leg_sprite.region_rect = LEG_REGIONS["default_left"]

func _apply_idle_sprites() -> void:
	# Snap the upper body container back to default center
	body.position.y = 0.0
	
	# Apply the base direction layouts (head, torso, hands)
	_apply_direction_sprites()
	
	# Override the lower body with static/idle frames
	match current_run_dir:
		RunDir.DOWN:
			leg_sprite.region_rect = LEG_REGIONS["default_down"]
			feet_sprite.region_rect = FEET_REGIONS["default_down"]
			shirt_sprite.region_rect = BODY_REGIONS["default_down"]  # ← add
			hand_sprite.region_rect = HAND_REGIONS["default_down"]   # ← add
		RunDir.RIGHT:
			leg_sprite.region_rect = LEG_REGIONS["default_right"]
			feet_sprite.region_rect = FEET_REGIONS["default_right"]
		RunDir.LEFT:
			leg_sprite.region_rect = LEG_REGIONS["default_left"]
			feet_sprite.region_rect = FEET_REGIONS["default_left"]
		RunDir.UP:
			leg_sprite.region_rect = LEG_REGIONS["default_up"]
			feet_sprite.region_rect = FEET_REGIONS["default_up"]

func _apply_animation_frame() -> void:
	var run_frames = get_run_frames()
	# Each array indexes itself independently now
	body.position.y = RUN_BOB_OFFSETS[current_run_frame % RUN_BOB_OFFSETS.size()]
	feet_sprite.region_rect = FEET_REGIONS[run_frames[current_run_frame % run_frames.size()]]
	if current_run_dir == RunDir.DOWN:
		var leg_frames = get_leg_frames()
		leg_sprite.region_rect = LEG_REGIONS[leg_frames[current_run_frame % leg_frames.size()]]
		var hand_frames = get_hand_frames()
		hand_sprite.region_rect = HAND_REGIONS[hand_frames[current_run_frame % hand_frames.size()]]
		var shirt_frames = get_shirt_frames()
		shirt_sprite.region_rect = BODY_REGIONS[shirt_frames[current_run_frame % shirt_frames.size()]]
		
func _physics_process(delta: float):
	if not is_multiplayer_authority():
		return
		
	Global.player_position = self.global_position
	
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if direction != Vector2.ZERO:
		direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()


func get_run_frames() -> Array:
	match current_run_dir:
		RunDir.LEFT:
			return RUN_FRAMES_LEFT
		RunDir.RIGHT:
			return RUN_FRAMES_RIGHT
		RunDir.DOWN:
			return RUN_FRAMES_DOWN
		_:
			return RUN_FRAMES_RIGHT # fallback for now
			
func get_leg_frames() -> Array:
	match current_run_dir:
		RunDir.DOWN:
			return LEG_FRAMES_DOWN
		_:
			return LEG_FRAMES_DOWN # fallback for now
			
func get_hand_frames() -> Array:
	match current_run_dir:
		RunDir.DOWN:
			return HAND_FRAMES_DOWN
		_:
			return [] # no hand animation for other directions yet
			
func get_shirt_frames() -> Array:
	match current_run_dir:
		RunDir.DOWN:
			return SHIRT_FRAMES_DOWN
		_:
			return [] # no hand animation for other directions yet

func _on_animation_timer_timeout():
	current_run_frame = (current_run_frame + 1) % MAX_ANIMATION_TICKS
	_apply_animation_frame()
	
func _on_eye_dart_timer_timeout():
	var random_direction = eye_directions.pick_random()
	change_eyes(random_direction)
	eye_dart_timer.wait_time = randf_range(1.0, 4.0)
	eye_dart_timer.start()

func _sync_reflection():
	for child in body.get_children():
		if child is Sprite2D:
			#print("Checking:", child.name)
			var mirror := reflection.get_node_or_null(NodePath(child.name))
			#print(mirror)
			if mirror == null:
				#print("❌ Missing mirror for:", child.name)
				continue
			#print("✅ Synced:", child.name)
			mirror.texture = child.texture
			mirror.region_enabled = child.region_enabled
			mirror.region_rect = child.region_rect
			#print(child.frame)
			mirror.flip_h = child.flip_h
			mirror.rotation = child.rotation
			mirror.modulate = child.modulate 
		
func change_eyes(expression: String):
	if EYE_REGIONS.has(expression):
		eye_sprite.region_rect = EYE_REGIONS[expression]
	else:
		print("Error: Eye expression not found: ", expression)
		
func change_skin_color(new_color: Color):
	head_sprite.modulate = new_color
	torso_sprite.modulate = new_color
	hand_sprite.modulate = new_color

func change_hair_color(new_color: Color):
	hair_sprite.modulate = new_color
	
func change_eye_color(new_color: Color):
	eye_sprite.modulate = new_color

func pickup_item(item_id: String, count: int) -> int:
	var item_data = ItemRegistry.get_item(item_id)
	if item_data.is_empty():
		return count
	var remaining = count
	# Fill existing stacks first
	for slot in inventory:
		if slot["item_id"] == item_id:
			var space = item_data["max_stack_size"] - slot["count"]
			var added = min(space, remaining)
			slot["count"] += added
			remaining -= added
			if remaining == 0:
				inventory_changed.emit(inventory)
				return 0
	# Then find empty slots
	for slot in inventory:
		if slot["item_id"] == "":
			var stack = min(remaining, item_data["max_stack_size"])
			slot["item_id"] = item_id
			slot["count"] = stack
			remaining -= stack
			if remaining == 0:
				inventory_changed.emit(inventory)
				return 0
	inventory_changed.emit(inventory)
	return remaining

func drop_item(slot_index: int) -> void:
	if slot_index >= inventory.size():
		return
	var slot = inventory[slot_index]
	if slot["item_id"] == "":
		return
	var throw_dir = (get_global_mouse_position() - global_position).normalized()
	var world_gen = get_tree().get_first_node_in_group("world_gen")
	if world_gen:
		world_gen.drop_item_at(get_tile_pos(), slot["item_id"], 1, throw_dir)
	slot["count"] -= 1
	if slot["count"] <= 0:
		slot["item_id"] = ""
		slot["count"] = 0
	inventory_changed.emit(inventory)

func get_tile_pos() -> Vector2i:
	return Vector2i(floori(global_position.x / 16.0), floori(global_position.y / 16.0))
	
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("drop_item"):
		var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
		if inventory_ui:
			drop_item(inventory_ui.selected_slot)

func expand_inventory(additional_slots: int) -> void:
	inventory_size += additional_slots
	for i in range(additional_slots):
		inventory.append({ "item_id": "", "count": 0 })
	inventory_changed.emit(inventory)
	# Tell the UI to add the new slots
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui:
		inventory_ui.add_slots(additional_slots)

func shrink_inventory(amount: int) -> void:
	var new_size = max(inventory_size - amount, 12)  # never go below starting size
	var actual_reduction = inventory_size - new_size
	
	# Collect items from slots that are being removed
	var displaced_items = []
	for i in range(new_size, inventory_size):
		if inventory[i]["item_id"] != "":
			displaced_items.append(inventory[i].duplicate())
	
	# Resize first
	inventory.resize(new_size)
	inventory_size = new_size
	
	# Try to fit displaced items into remaining empty slots
	for item in displaced_items:
		var leftover = pickup_item(item["item_id"], item["count"])
		# If inventory is full, drop to world
		if leftover > 0:
			var world_gen = get_tree().get_first_node_in_group("world_gen")
			if world_gen:
				world_gen.drop_item_at(get_tile_pos(), item["item_id"], leftover)
	
	inventory_changed.emit(inventory)
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui:
		inventory_ui.remove_slots(actual_reduction)
