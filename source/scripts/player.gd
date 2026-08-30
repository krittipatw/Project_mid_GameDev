extends CharacterBody2D


@export var SPEED = 120.0
@export var JUMP_VELOCITY = -300.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	#adding movement through input keys for left and right
	if Input.is_action_pressed("move_left"):
		velocity.x = -SPEED 
		animated_sprite.flip_h = true
		animated_sprite.play("run")
	elif Input.is_action_pressed("move_right"):
		velocity.x = SPEED
		animated_sprite.flip_h = false
		animated_sprite.play("run")
	#idle
	else:
		animated_sprite.play("idle")
		velocity.x = 0
	#handlig jump and gravity
	if is_on_floor() :
		#adding jump through input key for jump
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		#applying gravity 
		velocity += get_gravity() * delta
		animated_sprite.play("jump")
		
	move_and_slide()
