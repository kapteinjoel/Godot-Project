extends Label

func _process(_delta):
	var fps = Engine.get_frames_per_second()

	self.text = " FPS: " + str(fps) + "\n Lobby ID: " + str(SteamManager.current_lobby_id)
