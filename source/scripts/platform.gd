extends AnimatableBody2D


@export var onewayplatform = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _process(delta: float) -> void:
	#checking if onewayplatform is true or false
	if onewayplatform == true :
		collision_shape.one_way_collision = true
	else:
		collision_shape.one_way_collision = false
	
