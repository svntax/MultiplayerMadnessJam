extends Node2D

@onready var connected_peers : Dictionary = {}
@onready var room_capacity = 2
var multiplayer_peer = WebSocketMultiplayerPeer.new()

@onready var port_input = %PortInput
@onready var ip_address_input = %AddressInput
@onready var menu = $CanvasLayer/PanelContainer/Menu
@onready var network_info = $CanvasLayer/UI/NetworkInfo
@onready var panel_container = $CanvasLayer/PanelContainer
@onready var message_panel = %MessagePanel
@onready var message_label = %MessageLabel

@onready var players = $Players
@onready var bricks_player_1 = $BricksPlayer1
@onready var bricks_player_2 = $BricksPlayer2
@onready var player_1_spawn = $PlayerSpawn1
@onready var player_2_spawn = $PlayerSpawn2
@onready var ball_1 = %Ball1
@onready var ball_2 = %Ball2
@onready var winner = -1 # Which player won the match

# READY, GAMEPLAY, GAME_OVER
@onready var game_state = "READY" # TODO: handle player disconnect
@onready var countdown_time = 5
@onready var start_countdown_timer = $StartCountdownTimer
@onready var game_over_countdown_time = 10
@onready var game_over_countdown_timer = $GameOverCountdownTimer
@onready var win_check_timer = $WinCheckTimer

func _ready():
	message_panel.hide()
	if "--server" in OS.get_cmdline_args() and !(OS.has_feature("web")):
		start_lobby()
	else:
#		if OS.is_debug_build(): # DEBUG for local testing
#			return
		
		if Utils.ready_to_connect():
			join_room(Utils.room_host, Utils.room_port)
		else:
			# For some reason, client is unable to join the room, so go back.
			Utils.reset_room_data()
			network_info.text = "Failed to connect to room.\nReturning to main lobby..."
			await get_tree().create_timer(3.0).timeout
			get_tree().change_scene_to_file("res://UI/Screens/MainLobby.tscn")

func _on_join_button_pressed():
	join_room(ip_address_input.text, str(port_input.text).to_int())

func join_room(host: String, port: int) -> void:
	var client_tls_options = TLSOptions.client()
	multiplayer_peer.create_client("wss://" + str(host) + ":" + str(port), client_tls_options)
	multiplayer.multiplayer_peer = multiplayer_peer
	menu.hide()
	panel_container.hide()
	network_info.hide()

func add_player_character(peer_id):
	var character = preload("res://Player/Player.tscn").instantiate()
	character.name = str(peer_id)
	var peer_keys = connected_peers.keys()
	var index = peer_keys.find(str(peer_id))
	if index == 0:
		character.global_position = player_1_spawn.global_position
		character.player_name = "P1"
	elif index == 1:
		character.global_position = player_2_spawn.global_position
		character.player_name = "P2"
	players.add_child(character)
	
	if connected_peers.size() == 2:
		start_game_countdown()

func _on_start_pressed():
	start_lobby()

func start_lobby() -> void:
	print("Starting server...")
	multiplayer_peer.create_server(port_input.text.to_int())
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Server started!")
	
	multiplayer_peer.peer_connected.connect(
		func(new_peer_id):
			print("New peer connected: " + str(new_peer_id))
			print("Previous peers: " + str(connected_peers.keys()))
			if connected_peers.size() >= room_capacity:
				multiplayer_peer.disconnect_peer(new_peer_id)
				connected_peers.erase(str(new_peer_id))
			else:
				connected_peers[str(new_peer_id)] = true
				if connected_peers.size() >= room_capacity:
					multiplayer_peer.refuse_new_connections = true
				else:
					multiplayer_peer.refuse_new_connections = false
				await get_tree().create_timer(0.5).timeout
				add_player_character(new_peer_id)
			update_room_state()
	)
	
	multiplayer_peer.peer_disconnected.connect(
		func(peer_id):
			connected_peers.erase(str(peer_id))
			if connected_peers.size() < room_capacity:
				multiplayer_peer.refuse_new_connections = false
			# TODO: don't delete player, remove from match instead
			for player in players.get_children():
				if player.name == str(peer_id):
					player.queue_free()
			update_room_state()
	)
	
	menu.visible = false
	network_info.text = "Server"

# https://hathora.dev/api#tag/RoomV2/operation/GetActiveRoomsForProcess
func get_active_rooms_for_process(process_id: String):
	var url_format = "https://api.hathora.dev/rooms/v2/%s/list/%s/active"
	var url = url_format % [Utils.APP_ID, process_id]
	var hathora_dev_token = OS.get_environment("DEVELOPER_TOKEN")
	var headers = ["Authorization: Bearer " + hathora_dev_token]
	var response = await Utils.fetch(url, headers)
	if response == null:
		push_error("Failed to fetch active rooms for process: " + process_id)
		return
	
	var status_code = response[1]
	if status_code >= 400:
		push_error("Error " + str(status_code) + " when attempting to get active rooms for: " + process_id)
		return
	
	var body = response[3]
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("An error occurred when parsing response from: " + url)
		return
	
	var data : Array = json.get_data()
	return data

# https://hathora.dev/api#tag/LobbyV2/operation/SetLobbyState
func update_room_state() -> void:
	var process_id = OS.get_environment("HATHORA_PROCESS_ID")
	var rooms = await get_active_rooms_for_process(process_id)
	if rooms == null:
		push_error("Failed to get active rooms for: " + process_id)
		return
	
	# Assumes that a process has only 1 room
	var room_data = rooms[0]
	var room_id = room_data.get("roomId")
	var room_state = {
		"playerCount": connected_peers.size()
	}
	var url_format = "https://api.hathora.dev/lobby/v2/%s/setState/%s"
	var url = url_format % [Utils.APP_ID, room_id]
	var hathora_dev_token = OS.get_environment("DEVELOPER_TOKEN")
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + hathora_dev_token]
	var query = {
		"state": room_state
	}
	var query_json = JSON.stringify(query)
	
	var response = await Utils.fetch(url, headers, HTTPClient.METHOD_POST, query_json)
	if response == null:
		push_error("Failed to update room state.")
		return
	
	var status_code = response[1]
	if status_code >= 400:
		push_error("Error " + str(status_code) + " when attempting to update room state.")
		return
	
	var body = response[3]
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		push_error("An error occurred when parsing response from: " + url)
		return
	
	print("Successfully updated room state!")

func start_game_countdown() -> void:
	show_countdown_message(countdown_time)
	start_countdown_timer.start()
	for brick in bricks_player_1.get_children():
		brick.connect("brick_removed", _on_brick_removed)

func start_game() -> void:
	panel_container.hide()
	game_state = "GAMEPLAY"
	var rand_dir = Vector2(0, -1).rotated(deg_to_rad(randi_range(-70, 70)))
	ball_1.set_direction(rand_dir)
	ball_2.set_direction(rand_dir)

func show_countdown_message(count: int) -> void:
	message_panel.show()
	var suffix = " seconds"
	if count == 1:
		suffix = " second"
	message_label.text = "Starting game in:\n" + str(count) + suffix

func _on_brick_removed():
	check_winner()

func check_winner():
	if game_state == "GAME_OVER":
		return
	
	var message = ""
	if bricks_player_1.get_child_count() <= 0 or \
			(bricks_player_1.get_child_count() == 1 and bricks_player_1.get_child(0).is_queued_for_deletion()):
		# Player 1 won
		print("Player 1 won")
		winner = 1
		message = "Player 1 won!"
	elif bricks_player_2.get_child_count() <= 0 or \
			(bricks_player_2.get_child_count() == 1 and bricks_player_2.get_child(0).is_queued_for_deletion()):
		# Player 2 won
		print("Player 2 won")
		winner = 2
		message = "Player 2 won!"
	if not message.is_empty():
		message_panel.show()
		message_label.text = message + "\nClosing game in 10 seconds"
		game_over()
	else:
		# Hacky failsafe for win check
		if bricks_player_1.get_child_count() <= 2 or bricks_player_2.get_child_count() <= 2:
			win_check_timer.start()

func game_over() -> void:
	game_state = "GAME_OVER"
	ball_1.set_direction(Vector2.ZERO)
	ball_2.set_direction(Vector2.ZERO)
	game_over_countdown_timer.start()

func _on_start_countdown_timer_timeout():
	countdown_time -= 1
	if countdown_time <= 0:
		print("Game started!")
		message_panel.hide()
		start_game()
	else:
		show_countdown_message(countdown_time)
		start_countdown_timer.start()

func _on_game_over_countdown_timer_timeout():
	game_over_countdown_time -= 1
	if game_over_countdown_time <= 0:
		print("Closing room!")
		message_panel.hide()
		# TODO: send players back to main lobby
		connected_peers.clear()
		multiplayer_peer.close()
	else:
		message_panel.show()
		var msg_format = "Player %s won!\nClosing game in %s %s"
		var suffix = "seconds"
		if game_over_countdown_time == 1:
			suffix = "second"
		var msg = msg_format % [str(winner), str(game_over_countdown_time), suffix]
		message_label.text = msg
		game_over_countdown_timer.start()

func _on_win_check_timer_timeout():
	check_winner()
