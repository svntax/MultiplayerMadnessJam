extends Node2D

# Redirects the server to the game scene.
# Redirects the client to the main lobby.

func _ready():
	if "--server" in OS.get_cmdline_args() and !(OS.has_feature("web")):
		get_tree().change_scene_to_file("res://Main.tscn")
	else:
		get_tree().change_scene_to_file("res://UI/Screens/MainLobby.tscn")
