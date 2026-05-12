extends Label

func _process(_delta):
	var fps = Engine.get_frames_per_second()

	self.text = "FPS: " + str(fps) + "\nLobby ID: " + str(SteamManager.current_lobby_id)
