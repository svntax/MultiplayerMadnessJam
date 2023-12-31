extends CharacterBody2D

const SPEED = 128.0

@onready var player_controller = $PlayerController
@onready var body = $Body
@onready var camera = $Camera2D
@onready var synchronizer = $MultiplayerSynchronizer
@onready var input_synchronizer = $PlayerController/MultiplayerSynchronizer
@onready var name_label = $NameLabel

var player_name = ""

@onready var original_y = global_position.y

func _ready():
	name_label.text = name
	input_synchronizer.set_multiplayer_authority(str(name).to_int())
	if input_synchronizer.is_multiplayer_authority():
		camera.make_current()

func _physics_process(delta):
	if not synchronizer.is_multiplayer_authority():
		return
	
	if not player_name.is_empty():
		name_label.text = player_name

	velocity.y = 0
	var direction = player_controller.input_vector.limit_length()
	if direction:
		velocity.x = direction.x * SPEED
		#velocity.y = direction.y * SPEED
		if direction.x != 0:
			body.scale.x = sign(velocity.x)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		#velocity.y = move_toward(velocity.y, 0, SPEED)
	
	move_and_slide()
	global_position.y = original_y

# TODO: any action that requires a key press from the player (e.g. shoot ball, shoot lasers)
func do_action() -> void:
	pass
#	if is_on_floor():
#		velocity.y = JUMP_VELOCITY
