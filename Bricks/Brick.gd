@tool
extends CharacterBody2D

@onready var sprites = $Sprites

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
	queue_free()
