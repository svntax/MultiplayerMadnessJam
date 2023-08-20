extends Node2D

@onready var connected_peers : Dictionary = {}
@onready var room_capacity = 2
var multiplayer_peer = WebSocketMultiplayerPeer.new()

@onready var port_input = %PortInput
@onready var ip_address_input = %AddressInput
@onready var menu = $CanvasLayer/PanelContainer/Menu
@onready var network_info = $CanvasLayer/NetworkInfo
@onready var players = $Players

func _ready():
	if "--server" in OS.get_cmdline_args() and !(OS.has_feature("web")):
		start_lobby()
	else:
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
	multiplayer_peer.create_client("ws://" + str(host) + ":" + str(port))
	multiplayer.multiplayer_peer = multiplayer_peer
	menu.visible = false
	network_info.hide()

func add_player_character(peer_id):
	var character = preload("res://Player/Player.tscn").instantiate()
	character.name = str(peer_id)
	$Players.add_child(character)

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
				await get_tree().create_timer(1).timeout
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
