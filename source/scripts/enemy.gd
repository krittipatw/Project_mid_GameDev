extends CharacterBody2D


@export var SPEED = 80.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var ray_cast2: RayCast2D = $RayCast2D2

var direction = 1


func _physics_process(delta: float) -> void:
	#change direction according to which raycast is colliding
	if ray_cast.is_colliding():
		direction = -1
	if ray_cast2.is_colliding():
		direction = 1
	#handling movement 
	if is_on_floor():
		velocity.x = direction * SPEED
		animated_sprite_2d.play("run")
	#apply gravity
	else:
		velocity += get_gravity() * delta
	#flipping the sprite according to direction
	if direction == 1:
		animated_sprite_2d.flip_h = false
	else:
		animated_sprite_2d.flip_h = true
	move_and_slide()
