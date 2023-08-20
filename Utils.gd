extends Node

const APP_ID = "app-0e8af726-83e7-44ea-acdd-80f45d856d3e"

var player_token = ""

# Client-side data fields for the room that the player is/will connect to
var room_id = ""
var room_host = ""
var room_port = -1

func ready_to_connect() -> bool:
	return room_host != null and room_port > 0

func reset_room_data() -> void:
	room_id = ""
	room_host = ""
	room_port = -1

func fetch(url: String, headers: Array = [], method: int = HTTPClient.METHOD_GET, query: String = ""):
	var http = HTTPRequest.new()
	add_child(http)
	
	var error = http.request(url, headers, method, query)
	if error != OK:
		push_error("An error occurred when fetching: " + url)
		http.queue_free()
		return
	
	# [result, status code, response headers, body]
	var response = await http.request_completed
	if response[0] != OK:
		push_error("An error occurred when fetching: " + url)
		http.queue_free()
		return
	
	# Moved this to functions because sometimes need to parse response differently.
#	var body = response[3]
#	var json = JSON.new()
#	var err = json.parse(body.get_string_from_utf8())
#	if err != OK:
#		push_error("An error occurred when parsing response from: " + url)
#		http.queue_free()
#		return
	
	http.queue_free()
	
	return response
