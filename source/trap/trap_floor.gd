extends StaticBody2D

@export var damage: int = 1
@export var damage_cooldown: float = 1.0  # เวลากันดาเมจซ้ำระหว่างที่ยังแตะอยู่ (วิ)

@onready var blade_sprite: AnimatedSprite2D = $CollisionShape2D/Piece08

var _cooldown_left: float = 0.0

func _ready() -> void:
	blade_sprite.play("spin")

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

func _on_body_entered(body: Node2D) -> void:
	if _cooldown_left <= 0.0 and body.has_method("take_damage"):
		body.take_damage(damage)
		_cooldown_left = damage_cooldown
