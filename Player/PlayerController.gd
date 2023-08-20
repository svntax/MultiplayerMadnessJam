extends Node2D

@export var input_vector: Vector2 = Vector2()

@onready var synchronizer = $MultiplayerSynchronizer

func _physics_process(delta):
	if synchronizer.is_multiplayer_authority():
		input_vector.x = Input.get_axis("ui_left", "ui_right")
		input_vector.y = Input.get_axis("ui_up", "ui_down")
		
		if Input.is_action_just_pressed("ui_accept"):
			do_action.rpc_id(1) # Call to id 1, which is the server

@rpc("any_peer", "call_remote", "reliable")
func do_action() -> void:
	var player = get_parent()
	var sender_id = multiplayer.get_remote_sender_id()
	if player.name == str(sender_id):
		player.do_action()
