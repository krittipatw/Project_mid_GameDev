extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $Damage
@onready var damage_shape: CollisionShape2D = $Damage/CollisionShape2D

@export var damage_amount: int = 30
@export var target_position: Vector2       # ตำแหน่งที่ระเบิดจะไหลเข้ามาหยุด
@export var slide_speed: float = 300.0
@export var fuse_time: float = 1.0         # เวลานับถอยหลังก่อนระเบิด หลังไหลมาถึง

var bodies_in_blast: Array = []

func _ready() -> void:
	damage_area.monitoring = false
	damage_shape.disabled = true
	anim.play("ิidle")

	damage_area.body_entered.connect(_on_body_entered)
	damage_area.body_exited.connect(_on_body_exited)

	_slide_in()

func _slide_in() -> void:
	# ไหลเข้ามาจากตำแหน่งปัจจุบัน (ตั้งตำแหน่งเริ่มต้นไว้นอกจอตอนวาง node)
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_position, 
		global_position.distance_to(target_position) / slide_speed)
	await tween.finished

	await get_tree().create_timer(fuse_time).timeout
	_explode()

func _explode() -> void:
	anim.play("explode")   # Bomb2 -> Bomb3 -> Bomb4 -> Bomb5

	# เปิด damage ตอนเริ่มระเบิด
	damage_area.monitoring = true
	damage_shape.disabled = false

	# เช็คคนที่ยืนอยู่ในรัศมีตอนระเบิดพอดี (ไม่ต้องรอ body_entered)
	for body in damage_area.get_overlapping_bodies():
		_deal_damage(body)

	await anim.animation_finished

	# ปิด damage หลังระเบิดจบ
	damage_area.monitoring = false
	damage_shape.disabled = true

	queue_free()   # ระเบิดลูกนี้ใช้แล้วหายไป

func _on_body_entered(body: Node) -> void:
	_deal_damage(body)

func _on_body_exited(body: Node) -> void:
	bodies_in_blast.erase(body)

func _deal_damage(body: Node) -> void:
	if body.is_in_group("player") and not bodies_in_blast.has(body):
		bodies_in_blast.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
