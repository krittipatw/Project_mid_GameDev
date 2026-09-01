extends Area2D

@export var amount = 1

@onready var gamemanager: Node = %gamemanager
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _on_body_entered(body: Node2D) -> void:
	#check if the scene has a node called gamemanager ,if not the code doesnot excute after the return
	if gamemanager == null:
		return
	audio.play()
	#calling the method called from gamemnager and giving the value called amount to add 
	gamemanager._updatescore(amount)
	#waiting for the audio to finish
	await audio.finished
	#deleting the coin 
	queue_free()
