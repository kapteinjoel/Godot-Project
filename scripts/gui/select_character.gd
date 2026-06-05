extends Control

const CHARACTERS_DIR_PATH = "user://characters/"

# Get a reference to the container that will hold the character buttons.
@onready var character_list_container = $CenterContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var vbox = $CenterContainer/VBoxContainer

@onready var screen_width = get_viewport().size.x
@onready var screen_height = get_viewport().size.y

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Check if the character list container node was found.
	if character_list_container == null:
		print("Error: Node not found at path 'ScrollContainer/VBoxContainer'")
		return
	# Load the character buttons when the scene is ready.
	
	vbox.custom_minimum_size = Vector2(screen_width / 3, screen_height / 2)
	_load_character_buttons()

# This function reads the characters directory and creates a button for each character file.
func _load_character_buttons() -> void:
	# Clear any existing buttons to prevent duplicates.
	for child in character_list_container.get_children():
		child.queue_free()

	# Create a DirAccess object to interact with the file system.
	var dir = DirAccess.open(CHARACTERS_DIR_PATH)
	
	# Check if the directory exists. If not, print a message and exit.
	if dir == null:
		print("Character directory not found: " + CHARACTERS_DIR_PATH)
		return
	
	# Start at the first file in the directory.
	dir.list_dir_begin()

	# Loop through all files in the directory.
	var file_name = dir.get_next()
	# Loop through all files in the directory.

	while file_name != "":
		# We're looking for files that end with the ".json" extension.
		if file_name.ends_with(".json"):
			# 1. Create a new Panel node to be the container.
			var panel = Panel.new()
			# Make the panel expand to fill the grid cell it's placed in.
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			#panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			# Apply the minimum size to the panel, not the button.
			panel.custom_minimum_size = Vector2(screen_width / 3, screen_height / 6)

			# 2. Create the Button node.
			var character_button = Button.new()
			
			# Make the button fill the entire panel.
			#character_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			# Get the character name from the file name (e.g., "my_character.json" becomes "My character").
			var character_name = file_name.replace(".json", "").replace("_", " ").capitalize()
			
			# Set the button's text to the character name.
			character_button.text = character_name
			
			# Connect the button's 'pressed' signal to a new function.
			var file_path = CHARACTERS_DIR_PATH + file_name
			character_button.pressed.connect(_on_character_button_pressed.bind(file_path))
			
			# 3. Add the button as a child of the panel.
			panel.add_child(character_button)
			
			# 4. Add the panel (with the button inside it) to your GridContainer.
			character_list_container.add_child(panel)
		
		# Move to the next file in the directory.
		file_name = dir.get_next()

	# Stop the directory listing.
	dir.list_dir_end()

# This function is called every frame.
func _process(_delta: float) -> void:
	# The _delta parameter is unused, so we prefix it with an underscore.
	pass

# This function is called when a character button is pressed.
func _on_character_button_pressed(file_path: String) -> void:
	# Load the character data from the file.
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Error opening file: " + file_path)
		return
	
	var character_data_json = file.get_as_text()
	file.close()
	
	# Parse the JSON data back into a dictionary.
	var character_data = JSON.parse_string(character_data_json)
	
	if character_data != null:
		print("Loaded character: " + character_data.name)

		# Use data to start the game
		Global.character_data = character_data
		Global.game_controller.change_gui_scene("res://scenes/menus/select_world.tscn")
	else:
		print("Error parsing JSON for file: " + file_path)
		print("This may be due to a corrupted or old save file. Please try creating and saving a new character.")

func _on_back_button_pressed() -> void:
	Global.game_controller.change_gui_scene("res://scenes/menus/main_menu.tscn")

func _on_new_button_pressed() -> void:
	Global.game_controller.change_gui_scene("res://scenes/menus/create_character.tscn")
