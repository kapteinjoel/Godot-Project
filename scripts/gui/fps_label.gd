extends Label

func _process(_delta):
	var fps = Engine.get_frames_per_second()

	# In Godot 4, use OBJECT_COUNT and OBJECT_NODE_COUNT
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	self.text = " FPS: " + str(fps) + \
				"\n Nodes: " + str(node_count) + \
				"\n Objects: " + str(object_count) + \
				"\n Lobby ID: " + str(SteamManager.current_lobby_id)
