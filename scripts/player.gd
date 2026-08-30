extends CharacterBody2D

@export var speed: float = 100.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(_delta):
	# Dialogue / cutscenes hold this lock. Stand still and idle while it is on.
	if GameState.input_locked:
		velocity = Vector2.ZERO
		sprite.stop()
		sprite.frame = 0
		return

	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed

	if direction == Vector2.ZERO:
		sprite.stop()
		sprite.frame = 0
	else:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				sprite.play("Kiren_Walk_Right")
			else:
				sprite.play("Kiren_Walk_Left")
		else:
			if direction.y > 0:
				sprite.play("Kiren_Walk_Forward")
			else:
				sprite.play("Kiren_Walk_Backwards")

	move_and_slide()
