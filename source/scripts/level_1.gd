extends Node2D

@onready var gamecomplete: Panel = $CanvasLayer/gamecomplete
@onready var audio: AudioStreamPlayer = $gamefinished/AudioStreamPlayer

func _ready() -> void:
	gamecomplete.visible = false


func _on_restartbutton_pressed() -> void:
	get_tree().reload_current_scene()


func _on_gamefinished_body_entered(body: Node2D) -> void:
	audio.play()
	gamecomplete.visible = true
