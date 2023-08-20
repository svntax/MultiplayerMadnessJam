@tool
extends CharacterBody2D

signal brick_removed()

@onready var sprites = $Sprites
var game_ref = null
@onready var alive = true

enum BrickColor {BLUE, ORANGE, PURPLE, GREEN, RED}
@export var brick_color: BrickColor = BrickColor.BLUE :
	get:
		return brick_color
	set(value):
		brick_color = value
		for spr in $Sprites.get_children():
			if spr.name.to_lower().contains(BrickColor.keys()[brick_color].to_lower()):
				spr.show()
			else:
				spr.hide()

func _ready():
	if not Engine.is_editor_hint():
		brick_color = brick_color

func hit() -> void:
	if not alive:
		return
	
	alive = false
	hide()
	emit_signal("brick_removed")
	remove_brick.rpc()
	queue_free()

@rpc("authority", "call_remote", "reliable")
func remove_brick():
	queue_free()
