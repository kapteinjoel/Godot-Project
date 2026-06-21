class_name GameController extends Node

@export var game : Node2D
@export var gui : Control

var current_game_scene
var current_gui_scene

func _ready() -> void:
	Global.game_controller = self
	change_game_scene("res://scenes/game/game.tscn", false, false, func(instance): instance.get_node("World").preview_mode = true)
	change_gui_scene("res://scenes/menus/main_menu.tscn")
	
func _process(_delta) -> void:
	pass

func change_gui_scene(new_scene: String, delete: bool = true, keep_running: bool = false) -> void:
	if current_gui_scene != null:
		if delete:
			current_gui_scene.queue_free()
		elif keep_running:
			current_gui_scene.visible = false
		else:
			gui.remove_child(current_gui_scene)
	var new = load(new_scene).instantiate()
	gui.add_child(new)
	current_gui_scene = new

func change_game_scene(new_scene, delete: bool = true, keep_running: bool = false, pre_setup: Callable = Callable()) -> void:
	if current_game_scene != null:
		if delete:
			current_game_scene.queue_free()
		elif keep_running:
			current_game_scene.visible = false
		else:
			game.remove_child(current_game_scene)
	var new_instance
	if new_scene is String:
		new_instance = load(new_scene).instantiate()
	elif new_scene is PackedScene:
		new_instance = new_scene.instantiate()
		print('using preload')
	else:
		printerr("Invalid scene type passed to change_game_scene.")
		return
	if pre_setup.is_valid():
		pre_setup.call(new_instance)
	game.add_child(new_instance)
	current_game_scene = new_instance
	
