extends Node2D

var regions_list = [
	"Seattle",
	"Washington_DC",
	"Chicago",
	"London",
	"Frankfurt",
	"Mumbai",
	"Singapore",
	"Tokyo",
	"Sydney",
	"Sao_Paulo"
]

var RoomRow = preload("res://UI/RoomRow.tscn")

@onready var region_button = %RegionButton
@onready var create_button = %CreateButton
@onready var lobbies_container = %Lobbies
@onready var column_headers = %ColumnHeaders
@onready var message_panel = %MessagePanel
@onready var message_label = %MessageLabel
@onready var join_room_timer = $JoinRoomTimer
@onready var join_private_button = %JoinPrivateButton
@onready var room_code_input = %RoomCodeInput
@onready var refresh_button = %RefreshButton

func _ready():
	message_panel.hide()
	
	# NOTE: using hard-coded regions list instead
	#regions_list.clear()
	#await fetch_regions()
	
	for region_name in regions_list:
		region_button.add_item(region_name.replace("_", " "))
	
	login_anonymous()
	fetch_public_lobbies()

# https://hathora.dev/api#tag/AuthV1/operation/LoginAnonymous
func login_anonymous():
	var url_format = "https://api.hathora.dev/auth/v1/%s/login/anonymous"
	var url = url_format % Utils.APP_ID
	var response = await Utils.fetch(url, [], HTTPClient.METHOD_POST)
	if response == null:
		show_error_message("Failed to get anonymous login.")
		return
	
	var body = response[3]
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		show_error_message("An error occurred when parsing response from: " + url)
		return
	
	var data : Dictionary = json.get_data()
	var player_token = data.get("token", "")
	if player_token == "":
		show_error_message("Got invalid anonymous player token.")
		return
	
	#print("Obtained player token: " + player_token)
	Utils.player_token = player_token

# https://hathora.dev/api#tag/LobbyV2/operation/CreateLobby
func create_lobby(params: Dictionary):
	var url_format = "https://api.hathora.dev/lobby/v2/%s/create"
	var url = url_format % Utils.APP_ID
	var headers = ["Content-Type: application/json", "Authorization: " + Utils.player_token]
	var query = {
		"visibility": params.get("visibility"),
		"initialConfig": params.get("initial_config"),
		"region": params.get("region").replace(" ", "_")
	}
	var query_json = JSON.stringify(query)
	var response = await Utils.fetch(url, headers, HTTPClient.METHOD_POST, query_json)
	if response == null:
		show_error_message("Failed to create a lobby.")
		create_button.disabled = false
		return
	
	var status_code = response[1]
	if status_code >= 400:
		show_error_message("Error " + str(status_code) + " when attempting to create lobby.")
		create_button.disabled = false
		return
	
	var body = response[3]
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		show_error_message("An error occurred when parsing response from: " + url)
		return
	
	var room_data = json.get_data()
	Utils.room_id = room_data.get("roomId")
	print("Room data for created lobby:")
	print("roomId = " + room_data.get("roomId"))

# https://hathora.dev/api#tag/RoomV2/operation/GetConnectionInfo
func fetch_connection_info(room_id: String):
	var url_format = "https://api.hathora.dev/rooms/v2/%s/connectioninfo/%s"
	var url = url_format % [Utils.APP_ID, room_id]
	var response = await Utils.fetch(url)
	if response == null:
		show_error_message("Failed to fetch connection info for room: " + room_id)
		return
	
	var status_code = response[1]
	if status_code >= 400:
		show_error_message("Error " + str(status_code) + " when attempting to get connection info for: " + room_id)
		return
	
	var body = response[3]
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		show_error_message("An error occurred when parsing response from: " + url)
		return
	
	var data : Dictionary = json.get_data()
	var room_status = data.get("status")
	var exposed_port = data.get("exposedPort", null)
	if exposed_port == null or room_status != "active":
		return {"status": room_status}
	var host_name = exposed_port.get("host")
	var port = exposed_port.get("port")
	return {"host": host_name, "port": port, "status": room_status}

# https://hathora.dev/api#tag/LobbyV2/operation/ListActivePublicLobbies
func fetch_public_lobbies():
	var url_format = "https://api.hathora.dev/lobby/v2/%s/list/public"
	var url = url_format % Utils.APP_ID
	var response = await Utils.fetch(url)
	if response == null:
		show_error_message("Failed to fetch public lobbies.")
		return
	
	var status_code = response[1]
	if status_code >= 400:
		show_error_message("Error " + str(status_code) + " when attempting to get public lobbies.")
		return
	
	var body = response[3]
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		show_error_message("An error occurred when parsing response from: " + url)
		return
	
	var lobbies : Array = json.get_data()
	for lobby in lobbies:
		var room_row = RoomRow.instantiate()
		lobbies_container.add_child(room_row)
		room_row.set_room_id(lobby["roomId"])
		room_row.set_region(lobby["region"])
		var player_count_value = "?"
		var room_state = lobby["state"]
		if room_state != null:
			var player_count = str(room_state.get("playerCount"))
			if player_count.is_valid_int():
				player_count_value = player_count
		if player_count_value == "?":
			room_row.players_count.text = "?" # Directly set to fallback
		else:
			room_row.set_players_count(int(player_count_value), 2)
		room_row.connect("join_room", _on_join_room_attempt)
	
	if lobbies.is_empty():
		var label = Label.new()
		lobbies_container.add_child(label)
		label.text = "No lobbies found."

# NOTE: unused
# https://hathora.dev/api#tag/DiscoveryV1/operation/GetPingServiceEndpoints
#func fetch_regions():
#	var url = "https://api.hathora.dev/discovery/v1/ping"
#	var response = await Utils.fetch(url)
#	if response == null:
#		show_error_message("Failed to fetch regions.")
#		return
#
#	var body = response[3]
#	var json = JSON.new()
#	var err = json.parse(body.get_string_from_utf8())
#	if err != OK:
#		show_error_message("An error occurred when parsing response from: " + url)
#		return
#
#	var regions : Array = json.get_data()
#	for region in regions:
#		if region["region"]:
#			regions_list.append(region["region"])

func _on_create_button_pressed():
	var region_selected = region_button.text
	var room_visibility = "public" # TODO: private option
	var initial_config = {}
	var request_body = {
		"visibility": room_visibility,
		"initial_config": initial_config,
		"region": region_selected
	}
	create_button.disabled = true
	await create_lobby(request_body)
	join_room_timer.start()
	show_error_message("Joining room, please wait...")

func connect_to_room(room_id: String = Utils.room_id):
	if room_id == null:
		show_error_message("Error: attempted to connect to an invalid room id.")
		return
	
	var room_data = await fetch_connection_info(room_id)
	if room_data == null:
		show_error_message("Failed to get connection info for room: " + room_id)
		Utils.reset_room_data()
		create_button.disabled = false
		return
	
	var room_status = room_data.get("status")
	if room_status != "active":
		# Room still not active
		join_room_timer.start()
		return
	
	Utils.room_host = room_data.get("host")
	Utils.room_port = room_data.get("port")
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_join_room_attempt(room_id: String):
	Utils.room_id = room_id
	connect_to_room(Utils.room_id)

func show_error_message(message: String) -> void:
	push_error(message)
	if message_panel.visible:
		message_label.text += "\n---\n" + message
	else:
		message_label.text = message
		message_panel.show()

func _on_message_ok_button_pressed():
	message_panel.hide()
	message_label.text = ""

func _on_join_room_timer_timeout():
	connect_to_room()

# Refresh the lobbies list
func _on_refresh_button_pressed():
	refresh_button.disabled = true
	for child in lobbies_container.get_children():
		if child == column_headers:
			continue
		child.queue_free()
	
	await fetch_public_lobbies()
	refresh_button.disabled = false

func _on_join_private_button_pressed():
	join_private_button.disabled = true
	var private_room_id = room_code_input.text
	await connect_to_room(private_room_id)
	join_private_button.disabled = false

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://UI/Screens/TitleScreen.tscn")
