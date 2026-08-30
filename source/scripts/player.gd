extends CharacterBody2D

## Jump King Style Controller — พร้อมเชื่อม Animation
## แนบสคริปต์นี้กับ CharacterBody2D ที่มี child เป็น AnimatedSprite2D ชื่อ "AnimatedSprite2D"
## และ CollisionShape2D ตามปกติ

# ===== ค่าคงที่ที่ปรับได้ =====
@export var gravity: float = 1400.0
@export var move_speed_ground: float = 180.0   # ความเร็วเดินตอนอยู่บนพื้น
@export var move_speed_air: float = 60.0       # ความเร็วขยับตอนลอยกลางอากาศ (Jump King ขยับอากาศได้น้อยมาก)
@export var min_jump_force: float = 300.0
@export var max_jump_force: float = 900.0
@export var charge_rate: float = 900.0         # แรงที่เพิ่มขึ้นต่อวินาทีตอนกดค้าง
@export var max_charge_time: float = 1.2
@export var landing_lock_time: float = 0.25    # เวลาที่ขยับไม่ได้ตอนลงพื้น (ให้ตรงกับอนิเมชัน land)
@export var wall_bounce_force: float = 210.0   # แรงที่เด้งกลับตอนชนกำแพงกลางอากาศ
@export var wall_bounce_vertical_boost: float = 0.6  # สัดส่วนที่ดึงแรงตกลงมาแปลงเป็นแรงเด้งขึ้นนิดหน่อย (0 = ไม่บวกเลย)
@export var wall_stun_time: float = 0.25       # เวลาที่คุมทิศทางไม่ได้หลังโดนเด้ง (กันกดสู้แรงเด้งจนไม่รู้สึกว่าชน)

# ===== State Machine =====
enum State { IDLE, CHARGING, JUMPING, FALLING, LANDING }
var state: State = State.IDLE

var charge_time: float = 0.0
var facing: int = 1              # 1 = ขวา, -1 = ซ้าย
var jump_velocity: Vector2 = Vector2.ZERO
var landing_timer: float = 0.0
var wall_stun_timer: float = 0.0   # >0 = เพิ่งโดนเด้งกำแพง คุมทิศทางเองไม่ได้ชั่วขณะ

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	# แรงโน้มถ่วง ใส่ตลอด ยกเว้นตอนติดพื้นจริง ๆ
	if not is_on_floor():
		velocity.y += gravity * delta

	if wall_stun_timer > 0.0:
		wall_stun_timer = max(wall_stun_timer - delta, 0.0)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHARGING:
			_process_charging(delta)
		State.JUMPING, State.FALLING:
			_process_airborne(delta)
		State.LANDING:
			_process_landing(delta)

	move_and_slide()

	# เช็คชนกำแพงหลัง move_and_slide เท่านั้น ถึงจะรู้ผลชนที่ถูกต้องของเฟรมนี้
	if (state == State.JUMPING or state == State.FALLING) and wall_stun_timer <= 0.0 and is_on_wall():
		_bounce_off_wall()

	_update_animation()


# ---------- IDLE / WALK (เดินได้ปกติด้วย A/D) ----------
func _process_idle(_delta: float) -> void:
	var input_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_dir * move_speed_ground

	if input_dir != 0.0:
		facing = sign(input_dir)

	if Input.is_action_just_pressed("jump"):
		state = State.CHARGING
		charge_time = 0.0

	if not is_on_floor():
		state = State.FALLING


# ---------- CHARGING (กดปุ่มค้างเพื่อสะสมแรงกระโดด) ----------
func _process_charging(delta: float) -> void:
	velocity.x = 0.0

	# ยังหันทิศได้ระหว่างชาร์จ
	if Input.is_action_pressed("move_left"):
		facing = -1
	elif Input.is_action_pressed("move_right"):
		facing = 1

	charge_time = min(charge_time + delta, max_charge_time)

	if Input.is_action_just_released("jump"):
		_perform_jump()


func _perform_jump() -> void:
	var t: float = charge_time / max_charge_time
	var jump_force: float = lerp(min_jump_force, max_jump_force, t)

	# มุมกระโดด: ยิ่งชาร์จนาน ยิ่งพุ่งสูง+ไกล ปรับสัดส่วนตามที่ต้องการได้
	velocity.x = facing * jump_force * 0.5
	velocity.y = -jump_force

	state = State.JUMPING


# ---------- ลอยกลางอากาศ (ขึ้น/ตก) ----------
func _process_airborne(delta: float) -> void:
	# ระหว่างโดนเด้งกำแพง (wall_stun_timer > 0) ผู้เล่นคุมทิศทางเองไม่ได้ชั่วขณะ
	# ให้รู้สึกถึงแรงกระแทกจริง ๆ ไม่ใช่กดสวนแล้วหักลบแรงเด้งจนไม่รู้สึกอะไร
	if wall_stun_timer <= 0.0:
		var input_dir: float = Input.get_axis("move_left", "move_right")
		if input_dir != 0.0:
			velocity.x += input_dir * move_speed_air * delta
			facing = sign(input_dir)

	if velocity.y >= 0.0:
		state = State.FALLING

	if is_on_floor():
		_land()


# ---------- เด้งกลับเมื่อชนกำแพงกลางอากาศ ----------
func _bounce_off_wall() -> void:
	var wall_normal: Vector2 = get_wall_normal()
	# ใช้ wall normal เพื่อหาทิศเด้งที่ถูกต้อง (แม่นกว่าการเดาจาก velocity เฉย ๆ)
	var bounce_dir: float = wall_normal.x if wall_normal.x != 0.0 else -sign(velocity.x)
	bounce_dir = sign(bounce_dir) if bounce_dir != 0.0 else -facing

	velocity.x = bounce_dir * wall_bounce_force
	# ดึงแรงตกมาบวกเป็นแรงเด้งขึ้นนิดหน่อย ให้ดูมีน้ำหนัก ไม่ใช่แค่ลอยด้านข้าง
	velocity.y -= wall_bounce_force * wall_bounce_vertical_boost * 0.5

	facing = int(bounce_dir)
	wall_stun_timer = wall_stun_time
	state = State.FALLING


func _land() -> void:
	state = State.LANDING
	landing_timer = landing_lock_time
	velocity.x = 0.0


# ---------- LANDING (ล็อกการขยับสั้น ๆ ให้ตรงกับอนิเมชัน) ----------
func _process_landing(delta: float) -> void:
	velocity.x = 0.0
	landing_timer -= delta
	if landing_timer <= 0.0:
		state = State.IDLE


# ---------- เชื่อมอนิเมชัน ----------
func _update_animation() -> void:
	sprite.flip_h = (facing < 0)

	match state:
		State.IDLE:
			if is_on_floor() and abs(velocity.x) > 5.0:
				sprite.play("run")
			else:
				sprite.play("idle")
		State.CHARGING:
			# ใช้ animation_speed_scale ผูกกับ charge_time เพื่อให้เห็นการ "ย่อตัว" มากขึ้นเรื่อย ๆ
			var t: float = charge_time / max_charge_time
			sprite.play("charge")
			sprite.speed_scale = 1.0
			sprite.frame = int(t * (sprite.sprite_frames.get_frame_count("charge") - 1))
			sprite.stop() # หยุดที่เฟรมนั้น ไม่ให้เล่นวนเอง จนกว่าจะปล่อยปุ่ม
		State.JUMPING:
			sprite.play("jump")
		State.FALLING:
			if wall_stun_timer > 0.0 and sprite.sprite_frames.has_animation("wall_bounce"):
				sprite.play("wall_bounce")
			else:
				sprite.play("fall")
		State.LANDING:
			sprite.play("land")


# ---------- Input Map ที่ต้องตั้งใน Project Settings > Input Map ----------
# move_left  -> A / Left Arrow
# move_right -> D / Right Arrow
# jump       -> Space / Z (ปุ่มเดียว กดค้างชาร์จ ปล่อยเพื่อกระโดด)
#
# หมายเหตุ: ต้องมีอนิเมชันชื่อ "walk" ใน SpriteFrames ด้วย ไม่งั้นตอนเดินจะ error
# (idle, walk, charge, jump, fall, land — รวม 6 อนิเมชัน ขาดตัวใดตัวหนึ่งจะ error ตอน play())
#
# ระบบเด้งกำแพง: ไม่บังคับต้องมีอนิเมชันเพิ่ม จะใช้ "fall" เดิมเล่นระหว่างโดนเด้งก็ได้
# แต่ถ้าอยากให้มีท่าเฉพาะตอนกระแทกกำแพง ให้เพิ่มอนิเมชันชื่อ "wall_bounce" เข้าไป
# โค้ดจะเช็คอัตโนมัติว่ามีอนิเมชันนี้ไหม ถ้าไม่มีจะ fallback ไปเล่น "fall" แทนเอง
