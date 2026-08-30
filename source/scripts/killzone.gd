extends Area2D

## Kill Zone — ใช้กับหนาม/กับดัก/พื้นที่อันตรายที่แตะแล้วตายทันที
## ทำงานร่วมกับ jump_king_controller.gd — ต้องมีฟังก์ชัน die() อยู่ใน player script
## แนบสคริปต์นี้กับ Area2D ที่มี child เป็น Timer และ AudioStreamPlayer

@onready var timer: Timer = $Timer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

var player: Node = null   # เก็บ reference ผู้เล่นที่เดินเข้ามาโดนกับดักนี้ไว้ใช้ตอน timeout


func _on_body_entered(body: Node2D) -> void:
	# เช็คว่า body ที่ชนเข้ามามีฟังก์ชัน die() ไหม (กันไม่ให้ศัตรู/ของตกแต่งมาทริกเกอร์กับดักโดยไม่ตั้งใจ)
	if not body.has_method("die"):
		return

	# กันเรียกซ้ำถ้าผู้เล่นชนกับดักซ้ำ ๆ ระหว่างที่ timer กำลังนับถอยหลังอยู่แล้ว
	if timer.time_left > 0.0:
		return

	player = body
	audio.play()

	# ชะลอเวลาเกมลงครึ่งหนึ่งตอนโดนกับดัก ให้ความรู้สึกดราม่านิดนึงก่อนตายจริง
	Engine.time_scale = 0.5
	timer.start()


func _on_timer_timeout() -> void:
	# คืนเวลาเกมกลับเป็นปกติก่อนเสมอ ไม่งั้น state DEAD ของผู้เล่นจะโดน time_scale ที่ค้างไว้บิดเบือนไปด้วย
	Engine.time_scale = 1.0

	if player and player.has_method("die"):
		player.die()
		# ไม่ต้อง reload_current_scene() อีกต่อไป เพราะระบบ death/respawn
		# ใน jump_king_controller.gd จัดการเองอยู่แล้ว:
		# ผู้เล่นจะเข้า State.DEAD เล่นอนิเมชัน death แล้วรอกดปุ่มอะไรก็ได้เพื่อรีสปอว์นเอง
	else:
		# เผื่อกรณี player reference หาย (เช่น node ถูกลบไปก่อน) fallback กลับไป reload scene แทน
		get_tree().reload_current_scene()

	player = null
