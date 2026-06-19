# item_data.gd
class_name ItemData
extends Resource

@export var id: String              # "WOOD_LOG", "STONE" etc — must be unique
@export var display_name: String
@export var icon: Texture2D
@export var max_stack_size: int = 64
@export var description: String = ""
