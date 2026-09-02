extends CanvasLayer

## ติดสคริปต์นี้กับ CanvasLayer ที่ชื่อ "PauseUI"
## โครงสร้างที่คาดไว้:
## PauseUI (CanvasLayer, process_mode = Always)
##   ├── PauseButton (Button)
##   └── PausePanel (Control, ซ่อนไว้ตอนเริ่ม)
##         └── ... ResumeButton / RestartButton / LeaveButton

@onready var pause_button: Button = $PauseButton
@onready var pause_panel: Control = $PausePanel


func _ready() -> void:
	pause_panel.visible = false


func _on_pause_button_pressed() -> void:
	get_tree().paused = true
	pause_panel.visible = true


func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	pause_panel.visible = false


func _on_restart_button_pressed() -> void:
	# unpause ก่อนเสมอ ไม่งั้น scene ใหม่จะโหลดมาแบบ paused ค้าง
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_leave_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels/mainmenu.tscn")
