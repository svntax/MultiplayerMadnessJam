extends CharacterBody2D

const SPEED = 112.0

var direction = Vector2()

@onready var synchronizer = $MultiplayerSynchronizer

func set_direction(dir: Vector2) -> void:
	direction.x = dir.x
	direction.y = dir.y
	direction = direction.normalized()

# TODO: ball sometimes pushes the paddle
func _physics_process(delta):
	if not synchronizer.is_multiplayer_authority():
		return
	
	var collision = move_and_collide(direction * SPEED * delta)
	if collision:
		var reflection = collision.get_remainder().bounce(collision.get_normal())
		direction = direction.bounce(collision.get_normal())
		#move_and_collide(reflection)
		var collider = collision.get_collider()
		if collider != null and collider.has_method("hit"):
			collider.hit()
