extends HBoxContainer

signal join_room(room_id)

@onready var room_id = $RoomId
@onready var players_count = $PlayersCount
@onready var region = $Region
@onready var join_button = $JoinButton

func set_room_id(value: String) -> void:
	room_id.text = value
	room_id.tooltip_text = value

func set_players_count(value: int, max: int) -> void:
	players_count.text = str(value) + "/" + str(max)
	if value < max:
		join_button.disabled = false
	else:
		join_button.disabled = true

func set_region(region_name: String) -> void:
	region.text = region_name
	region.tooltip_text = region_name

func _on_join_button_pressed():
	emit_signal("join_room", room_id.text)
