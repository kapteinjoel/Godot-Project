extends Control

@onready var container: Control = $CanvasLayer/Control

func _ready() -> void:
	container.modulate.a = 1.0
	await get_tree().create_timer(2.5).timeout
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	Global.game_controller.change_gui_scene("res://scenes/menus/main_menu.tscn")
