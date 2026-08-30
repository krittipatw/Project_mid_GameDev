extends Area2D

@onready var timer: Timer = $Timer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

func _on_body_entered(body: Node2D) -> void:
	audio.play()
	#reducing the engine time by half on player entered
	Engine.time_scale = 0.5
	timer.start()

func _on_timer_timeout() -> void:
	#engine time back to normal
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
