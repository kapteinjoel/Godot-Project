extends Control

const CHARACTERS_DIR_PATH = "user://characters/"

# Get a reference to the container that will hold the character buttons.
@onready var character_list_container = $CanvasLayer/CenterContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var vbox = $CanvasLayer/CenterContainer/VBoxContainer

@onready var screen_width = get_viewport().size.x / 4
@onready var screen_height = get_viewport().size.y / 4

func _ready() -> void:
	vbox.custom_minimum_size = Vector2(screen_width / 3, screen_height)
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

	while file_name != "":
		if file_name.ends_with(".json"):
			# Create a new Panel node to be the container.
			var panel = Panel.new()
			
			# Make the panel expand to fill the grid cell it's placed in.
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			# Apply the minimum size to the panel, not the button.
			panel.custom_minimum_size = Vector2(screen_width / 3, screen_height / 6)

			# Create the Button node.
			var character_button = Button.new()
	
			
			# Get the character name from the file name.
			var character_name = file_name.replace(".json", "").replace("_", " ").capitalize()
			
			# Set the button's text to the character name.
			character_button.text = character_name
			
			# Connect the button's 'pressed' signal to a new function.
			var file_path = CHARACTERS_DIR_PATH + file_name
			character_button.pressed.connect(_on_character_button_pressed.bind(file_path))
			
			# Add the button as a child of the panel.
			panel.add_child(character_button)
			
			# Add the panel (with the button inside it) to your GridContainer.
			character_list_container.add_child(panel)
		
		# Move to the next file in the directory.
		file_name = dir.get_next()

	# Stop the directory listing.
	dir.list_dir_end()

func _process(_delta: float) -> void:
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

		# Use data to load the character in once a world is selected. 
		Global.character_data = character_data
		Global.game_controller.change_gui_scene("res://scenes/menus/select_world.tscn")
	else:
		print("Error parsing JSON for file: " + file_path)
		print("This may be due to a corrupted or old save file. Please try creating and saving a new character.")

func _on_back_button_pressed() -> void:
	Global.game_controller.change_gui_scene("res://scenes/menus/main_menu.tscn")

func _on_new_button_pressed() -> void:
	Global.game_controller.change_gui_scene("res://scenes/menus/create_character.tscn")
