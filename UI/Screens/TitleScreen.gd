extends Node2D

@onready var paddle = $Paddle
@onready var paddle_velocity = -1

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://UI/Screens/MainLobby.tscn")

func _process(delta):
	paddle.global_position.x += paddle_velocity
	if paddle.global_position.x <= 32:
		paddle_velocity = 1
	if paddle.global_position.x >= 288:
		paddle_velocity = -1
