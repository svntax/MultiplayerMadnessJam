extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -300.0

@onready var player_controller = $PlayerController
@onready var body = $Body
@onready var camera = $Camera2D
@onready var synchronizer = $MultiplayerSynchronizer
@onready var input_synchronizer = $PlayerController/MultiplayerSynchronizer
@onready var name_label = $NameLabel

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	#synchronizer.set_multiplayer_authority(str(name).to_int()) # From old P2P example
	name_label.text = name
	input_synchronizer.set_multiplayer_authority(str(name).to_int())
	if input_synchronizer.is_multiplayer_authority():
		camera.make_current()

func _physics_process(delta):
	if not synchronizer.is_multiplayer_authority():
		return

	var direction = player_controller.input_vector.limit_length()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.y = direction.y * SPEED
		if direction.x != 0:
			body.scale.x = sign(velocity.x)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
	
	move_and_slide()

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
