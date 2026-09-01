extends CharacterBody2D

## Jump King Style Controller — พร้อมเชื่อม Animation
## แนบสคริปต์นี้กับ CharacterBody2D ที่มี child เป็น AnimatedSprite2D ชื่อ "AnimatedSprite2D"
## และ CollisionShape2D ตามปกติ

# ===== ค่าคงที่ที่ปรับได้ =====
@export var gravity: float = 1400.0
@export var move_speed_ground: float = 240.0   # ความเร็วเดินตอนอยู่บนพื้น
@export var move_speed_air: float = 60.0       # ความเร็วขยับตอนลอยกลางอากาศ (Jump King ขยับอากาศได้น้อยมาก)
@export var min_jump_force: float = 300.0
@export var max_jump_force: float = 750.0
@export var charge_rate: float = 750.0         # แรงที่เพิ่มขึ้นต่อวินาทีตอนกดค้าง
@export var max_charge_time: float = 1.2
@export var landing_lock_time: float = 0.25    # เวลาที่ขยับไม่ได้ตอนลงพื้น (ให้ตรงกับอนิเมชัน land)
@export var wall_bounce_force: float = 210.0   # แรงที่เด้งกลับตอนชนกำแพงกลางอากาศ
@export var wall_bounce_vertical_boost: float = 0.6  # สัดส่วนที่ดึงแรงตกลงมาแปลงเป็นแรงเด้งขึ้นนิดหน่อย (0 = ไม่บวกเลย)
@export var wall_stun_time: float = 0.25       # เวลาที่คุมทิศทางไม่ได้หลังโดนเด้ง (กันกดสู้แรงเด้งจนไม่รู้สึกว่าชน)
@export var max_health: int = 3                # เลือดสูงสุด หมดแล้วตาย

# ===== Fall Damage: อิงความสูงที่ตกจริง (px) แทนความเร็วตอนกระแทกพื้น =====
@export var fall_damage_height: float = 300.0     # ตกเกินความสูงนี้ (px) เริ่มโดนดาเมจ ต่ำกว่านี้ตกฟรีไม่เจ็บ
@export var fall_death_height: float = 650.0      # ตกเกินความสูงนี้ ตายทันที ไม่ว่าเลือดเหลือเท่าไหร่

@export var death_input_lock_time: float = 0.4    # เวลาขั้นต่ำหลังตายก่อนจะรับ input รีสปอว์น (กันกดมั่วตอนกำลังล้มแล้วรีทันที)

# ===== Attack (คลิกซ้ายเพื่อโจมตี) =====
@export var attack_duration: float = 0.3     # ความยาวของท่าโจมตี (ล็อกการขยับระหว่างนี้) ให้ตรงกับความยาวอนิเมชัน "attack"
@export var attack_cooldown: float = 0.15    # เวลาพักหลังโจมตีจบ ก่อนจะโจมตีซ้ำได้อีกครั้ง
@export var attack_damage: int = 1           # ค่าดาเมจที่จะส่งให้ศัตรู (ใช้ตอนต่อระบบ hitbox จริง)

# ===== State Machine =====
enum State { IDLE, CHARGING, JUMPING, FALLING, LANDING, WALL_BOUNCE, ATTACK, DEAD }
var state: State = State.IDLE

var charge_time: float = 0.0
var facing: int = 1              # 1 = ขวา, -1 = ซ้าย
var jump_velocity: Vector2 = Vector2.ZERO
var landing_timer: float = 0.0
var wall_stun_timer: float = 0.0   # นับถอยหลังตอนอยู่ใน State.WALL_BOUNCE (คุมทิศทางเองไม่ได้เลยจนกว่าจะหมด)
var attack_timer: float = 0.0          # นับถอยหลังตอนอยู่ใน State.ATTACK
var attack_cooldown_timer: float = 0.0 # นับถอยหลังหลังโจมตีจบ ก่อนจะโจมตีซ้ำได้

# --- ตัวแปรใหม่สำหรับวัด fall damage จากความสูง ---
var was_grounded: bool = true      # เก็บสถานะ is_on_floor() ของเฟรมก่อนหน้า ใช้จับจังหวะ "เพิ่งหลุดจากพื้น"
var fall_start_y: float = 0.0      # ค่า Y ของจุดสูงสุด (ค่า Y น้อยที่สุด) ที่เคยขึ้นไปถึงระหว่างลอยอยู่รอบปัจจุบัน
									# หมายเหตุ: แกน Y ของ Godot ชี้ลง ดังนั้น "อยู่สูง" = ค่า Y น้อย

var current_health: int
var death_timer: float = 0.0          # นับเวลาตั้งแต่ตาย ใช้กันกดรีสปอว์นเร็วเกินไป
var respawn_position: Vector2          # จุดที่จะเกิดใหม่ (default = ตำแหน่งเริ่มเกมของตัวละคร)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_health = max_health
	respawn_position = global_position   # จำตำแหน่งเริ่มต้นไว้เป็นจุดรีสปอว์น
	fall_start_y = global_position.y
	# ถ้าอยากกำหนดจุดรีสปอว์นเอง (เช่น checkpoint) ให้เซ็ต respawn_position ใหม่จากที่อื่นได้ตลอดเวลา


func _physics_process(delta: float) -> void:
	# แรงโน้มถ่วง ใส่ตลอด ยกเว้นตอนติดพื้นจริง ๆ
	if not is_on_floor():
		velocity.y += gravity * delta

	# ---------- จับความสูงที่ตก (แทนความเร็ว) ----------
	# is_on_floor() ตอนต้นเฟรมนี้ยังสะท้อนผลลัพธ์จาก move_and_slide() ของเฟรมก่อนหน้า
	if is_on_floor():
		was_grounded = true
	else:
		if was_grounded:
			# เพิ่งหลุดจากพื้น ไม่ว่าจะเดินตกขอบหรือเพิ่งกระโดด -> เริ่มจับจุดสูงสุดใหม่
			fall_start_y = global_position.y
		was_grounded = false
		# อัปเดตจุดสูงสุด (ค่า Y น้อยสุด) ที่เคยขึ้นไปถึงระหว่างลอยอยู่รอบนี้
		# ครอบคลุมทั้งช่วงขาขึ้น (กระโดด) และกันเคสโดนเด้งกำแพงแล้วลอยขึ้นเพิ่มอีกระหว่างตก
		fall_start_y = min(fall_start_y, global_position.y)

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# คลิกซ้าย = โจมตี (ต้องยืนอยู่บนพื้นและว่างอยู่ ไม่ใช่กำลังชาร์จ/เด้งกำแพง/ตาย/โจมตีค้าง)
	# ถ้าอยากให้โจมตีกลางอากาศได้ด้วย ให้เพิ่ม State.JUMPING, State.FALLING เข้าไปในเงื่อนไขนี้
	if state == State.IDLE and attack_cooldown_timer <= 0.0 \
			and Input.is_action_just_pressed("attack"):
		_start_attack()

	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHARGING:
			_process_charging(delta)
		State.JUMPING, State.FALLING:
			_process_airborne(delta)
		State.WALL_BOUNCE:
			_process_wall_bounce(delta)
		State.LANDING:
			_process_landing(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DEAD:
			_process_dead(delta)

	move_and_slide()

	# เช็คชนกำแพงหลัง move_and_slide เท่านั้น ถึงจะรู้ผลชนที่ถูกต้องของเฟรมนี้
	# เช็คเฉพาะตอนกำลังขึ้น/ตกอยู่ ไม่เช็คซ้ำระหว่างที่กำลังเด้งอยู่แล้ว (กันเด้งซ้อนเด้ง)
	if (state == State.JUMPING or state == State.FALLING) and is_on_wall():
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
	# Jump King ปรับทิศตอนลอยได้นิดเดียว ไม่ใช่เดินเต็มสปีด
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

	facing = int(bounce_dir)       # หันหน้าตามทิศที่เด้งออกมา
	wall_stun_timer = wall_stun_time
	state = State.WALL_BOUNCE


# ---------- WALL_BOUNCE (ล็อกทิศทางเต็มที่ ผู้เล่นคุมไม่ได้จนกว่าจะหมดเวลา) ----------
func _process_wall_bounce(delta: float) -> void:
	# ล็อก velocity.x ไว้ตลอดช่วงนี้ ไม่รับ input ใด ๆ ทั้งซ้ายขวา
	# (ปล่อยให้ gravity ดึง velocity.y ต่อไปตามปกติ เพื่อให้พาราโบลาการเด้งดูเป็นธรรมชาติ)
	wall_stun_timer -= delta

	if wall_stun_timer <= 0.0:
		# หมดเวลาล็อกแล้ว กลับไปเป็นสถานะลอยตามปกติ ตามทิศ velocity.y ตอนนั้น
		state = State.JUMPING if velocity.y < 0.0 else State.FALLING
		return

	if is_on_floor():
		_land()


# ---------- เริ่มโจมตี (คลิกซ้าย) ----------
func _start_attack() -> void:
	state = State.ATTACK
	attack_timer = attack_duration
	velocity.x = 0.0
	# TODO: ตรงนี้เหมาะกับการเปิด hitbox/Area2D สำหรับเช็คชนศัตรู แล้วส่ง attack_damage ให้เป้าหมาย
	# เช่น $AttackHitbox.monitoring = true แล้วปิดอีกทีตอนจบ state (หรือใช้ AnimationPlayer track เปิด-ปิดเอง)


# ---------- ATTACK (ล็อกการขยับระหว่างเล่นท่าโจมตี) ----------
func _process_attack(delta: float) -> void:
	velocity.x = 0.0
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_cooldown_timer = attack_cooldown
		state = State.IDLE


func _land() -> void:
	# ความสูงที่ตกจริง = ตำแหน่ง Y ตอนแตะพื้น ลบ ตำแหน่ง Y ของจุดสูงสุดที่เคยขึ้นไปถึง
	var fall_distance: float = global_position.y - fall_start_y

	if fall_distance >= fall_death_height:
		# ตกสูงเกินขีดสุด ตายทันทีไม่ว่าเลือดจะเหลือเท่าไหร่
		_die()
		return

	if fall_distance >= fall_damage_height:
		current_health -= 1
		if current_health <= 0:
			_die()
			return
		# TODO: จุดนี้เหมาะกับการเรียก hit-flash / SFX เจ็บ / อัปเดต UI เลือด

	state = State.LANDING
	landing_timer = landing_lock_time
	velocity.x = 0.0


# ---------- ตาย: หยุดนิ่งกับที่ รอผู้เล่นกดปุ่มอะไรก็ได้เพื่อรีสปอว์น ----------
func die() -> void:
	# ฟังก์ชันสาธารณะ ให้ node ภายนอก (เช่น killzone, หนาม, กับดัก) เรียกใช้ได้โดยตรง
	# เช่น: player.die() จากสคริปต์กับดัก แทนการ reload scene ทั้งหมด
	_die()


func _die() -> void:
	state = State.DEAD
	death_timer = 0.0
	velocity = Vector2.ZERO
	# TODO: จุดนี้เหมาะกับการเรียก SFX ตาย / หยุดเวลา / เอฟเฟกต์กล้อง ฯลฯ


# ---------- นอนรอตาย: ไม่ขยับ ไม่รับ input เดิน/กระโดดใด ๆ ทั้งสิ้น ----------
func _process_dead(_delta: float) -> void:
	velocity.x = 0.0
	death_timer += _delta
	# การรีสปอว์นจริง ๆ เกิดขึ้นใน _input() ด้านล่าง ไม่ใช่ตรงนี้
	# เพราะอยากตรวจจับ "การกดปุ่มครั้งแรก" ไม่ใช่เช็คทุกเฟรมด้วย is_action_pressed (จะรีซ้ำถ้ากดค้าง)


# ---------- รีสปอว์นกลับไปจุดเริ่มต้น ----------
func _respawn() -> void:
	global_position = respawn_position
	velocity = Vector2.ZERO
	current_health = max_health
	fall_start_y = respawn_position.y
	was_grounded = true
	wall_stun_timer = 0.0
	landing_timer = 0.0
	charge_time = 0.0
	state = State.IDLE


# ---------- ดักการกดปุ่ม "อะไรก็ได้" ตอนตายอยู่ เพื่อรีสปอว์น ----------
func _input(event: InputEvent) -> void:
	if state != State.DEAD:
		return

	# กันกดมั่วตอนเพิ่งตายใหม่ ๆ (เช่นค้างปุ่มตอนตกตายพอดี)
	if death_timer < death_input_lock_time:
		return

	var is_any_button_press: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)

	if is_any_button_press:
		_respawn()


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
				_play_animation("run")
			else:
				_play_animation("idle")
		State.CHARGING:
			# ใช้ animation_speed_scale ผูกกับ charge_time เพื่อให้เห็นการ "ย่อตัว" มากขึ้นเรื่อย ๆ
			var t: float = charge_time / max_charge_time
			_play_animation("charge")
			sprite.speed_scale = 1.0
			sprite.frame = int(t * (sprite.sprite_frames.get_frame_count("charge") - 1))
			sprite.stop() # หยุดที่เฟรมนั้น ไม่ให้เล่นวนเอง จนกว่าจะปล่อยปุ่ม
		State.JUMPING:
			_play_animation("jump")
		State.FALLING:
			_play_animation("fall")
		State.WALL_BOUNCE:
			# ถ้ายังไม่มีอนิเมชันเฉพาะ ให้ fallback ไปเล่น "fall" แทนอัตโนมัติ
			if sprite.sprite_frames.has_animation("wall_bounce"):
				_play_animation("wall_bounce")
			else:
				_play_animation("fall")
		State.LANDING:
			_play_animation("land")
		State.ATTACK:
			_play_animation("attack")
		State.DEAD:
			# เล่นครั้งเดียวตอนเพิ่งเข้าสถานะ DEAD เท่านั้น ไม่เรียกซ้ำทุกเฟรม
			# เพราะถ้าอนิเมชัน "death" ตั้ง loop ไว้ปิด (ควรปิด) การเรียก play() ซ้ำจะทำให้เด้งกลับไปเฟรม 0 ทุกครั้ง
			# ผลคือมันจะไม่มีวัน "ค้าง" อยู่เฟรมสุดท้ายแบบที่ต้องการ (นอนแน่นิ่งอยู่ตรงนั้น)
			if sprite.animation != "death":
				_play_animation("death")


# ---------- เล่นอนิเมชัน + ปรับขนาดตามที่กำหนดไว้ใน animation_scales ----------
func _play_animation(anim_name: String) -> void:
	sprite.play(anim_name)
	# ถ้าไม่ได้ระบุไว้ใน dictionary จะใช้ Vector2(1,1) เป็นค่าเริ่มต้น (ขนาดปกติ)



# ---------- Input Map ที่ต้องตั้งใน Project Settings > Input Map ----------
# move_left  -> A / Left Arrow
# move_right -> D / Right Arrow
# jump       -> Space / Z (ปุ่มเดียว กดค้างชาร์จ ปล่อยเพื่อกระโดด)
# attack     -> Left Mouse Button (คลิกซ้าย)
#   วิธีเพิ่ม: Project Settings > Input Map > พิมพ์ชื่อ action ว่า "attack" ในช่อง > กด Add
#   จากนั้นกดปุ่ม "+" ข้าง action ที่สร้าง แล้วคลิกซ้ายเมาส์ค้างไว้ 1 ครั้งเพื่อจับ event ปุ่มซ้าย
#
# หมายเหตุ: ต้องมีอนิเมชันชื่อ "walk" ใน SpriteFrames ด้วย ไม่งั้นตอนเดินจะ error
# (idle, walk, charge, jump, fall, land, attack, death — อย่างน้อย 8 อนิเมชัน ขาดตัวใดตัวหนึ่งจะ error ตอน play())
# ("wall_bounce" ไม่บังคับ มี fallback ไปเล่น "fall" แทนถ้าไม่มี — ดูหมายเหตุด้านล่าง)
#
# ระบบเด้งกำแพง: ไม่บังคับต้องมีอนิเมชันเพิ่ม จะใช้ "fall" เดิมเล่นระหว่างโดนเด้งก็ได้
# แต่ถ้าอยากให้มีท่าเฉพาะตอนกระแทกกำแพง ให้เพิ่มอนิเมชันชื่อ "wall_bounce" เข้าไป
# โค้ดจะเช็คอัตโนมัติว่ามีอนิเมชันนี้ไหม ถ้าไม่มีจะ fallback ไปเล่น "fall" แทนเอง
#
# ตอนโดนเด้ง ตัวละครจะเข้า State.WALL_BOUNCE ซึ่งล็อกทิศทางเต็มที่ (ไม่รับ input ซ้าย/ขวาเลย)
# จนกว่า wall_stun_time จะหมด ถึงจะคืนคอนโทรลกลับไปให้ผู้เล่น — ปรับความยาวของการล็อกได้ที่ wall_stun_time
#
# ---------- ปรับขนาดแยกแต่ละอนิเมชัน ----------
# แก้ได้ตรง ๆ ที่ตัวแปร animation_scales ด้านบน (หรือปรับใน Inspector ก็ได้ เพราะเป็น @export)
# key = ชื่ออนิเมชัน, value = Vector2(scale_x, scale_y)
# ตัวไหนไม่ได้ใส่ไว้ในลิสต์ จะใช้ Vector2(1,1) (ขนาดปกติ) โดยอัตโนมัติ
# เวลาเปลี่ยนอนิเมชัน ฟังก์ชัน _play_animation() จะปรับ sprite.scale ให้เองทุกครั้ง
# ไม่กระทบกับอนิเมชันอื่น เพราะแยก key ต่อชื่ออนิเมชันชัดเจน ไม่ใช่ปรับที่ node ตรง ๆ แบบเดิม
#
# ---------- ระบบ Fall Damage / ตาย / รีสปอว์น (อิงความสูง) ----------
# ต้องมีอนิเมชันชื่อ "death" ใน SpriteFrames เพิ่มเข้ามาด้วย (รวมเป็น 8 อนิเมชันทั้งหมด)
# **สำคัญมาก**: อนิเมชัน "death" ต้องปิด Loop ไว้ (ในแท็บ Animation ของ SpriteFrames กดปุ่ม Loop ให้เป็นสีเทา/ปิด)
# ถ้าเปิด Loop ไว้ ตัวละครจะเล่นอนิเมชันตายวนซ้ำไปเรื่อย ๆ แทนที่จะค้างนิ่งอยู่เฟรมสุดท้าย
#
# วิธีทำงาน:
# 1. ทุกเฟรมที่ไม่ได้ติดพื้น ระบบจะจับ "จุดสูงสุด" (fall_start_y) ที่ตัวละครเคยขึ้นไปถึง
#    ไม่ว่าจะเป็นตอนกระโดดขึ้น หรือเดินตกขอบ platform โดยตรง
# 2. พอแตะพื้น (_land) จะคำนวณ fall_distance = ตำแหน่ง Y ตอนแตะพื้น - fall_start_y
#    แล้วเทียบกับ fall_damage_height / fall_death_height
#    - ตกต่ำกว่า fall_damage_height        -> ตกฟรี ไม่เจ็บ
#    - อยู่ระหว่างสอง threshold            -> โดนดาเมจ 1 หน่วย (ปรับจำนวนเลือดที่หายได้ในโค้ด _land())
#    - สูงกว่า fall_death_height           -> ตายทันที ไม่สนใจเลือดที่เหลือ
# 3. ตายแล้วเข้า State.DEAD ตัวละครจะนิ่งสนิท ไม่รับ input เดิน/กระโดดใด ๆ ทั้งสิ้น
# 4. ต้องรอ death_input_lock_time วินาทีก่อน ถึงจะเริ่มรับปุ่มกดเพื่อรีสปอว์น (กันกดมั่วตอนเพิ่งตาย)
# 5. หลังจากนั้น กดปุ่มอะไรก็ได้ (คีย์บอร์ด/เมาส์/จอย) หนึ่งครั้ง -> เรียก _respawn() ทันที
#    ถ้าไม่กดอะไรเลย ตัวละครจะนอนค้างอยู่ตรงนั้น "ตลอดไป" ตามที่ต้องการ
# 6. _respawn() จะเทเลพอร์ตกลับไปที่ respawn_position (ค่าเริ่มต้น = ตำแหน่งตอนเกมเริ่ม เก็บไว้ใน _ready())
#    ถ้าอยากทำระบบ checkpoint ให้ไปเซ็ต player.respawn_position = จุดนั้น ๆ จากสคริปต์ checkpoint ได้เลย
#
# ปรับความยากได้ที่ max_health, fall_damage_height, fall_death_height ตามความรู้สึกที่ต้องการ
# ค่าเริ่มต้น 250 / 550 (px) เหมาะกับ tile ขนาด ~32-64px — ถ้า level ของคุณใช้สเกลต่างจากนี้ ให้ปรับสองค่านี้ตามจริง
#
# ---------- ระบบโจมตี (คลิกซ้าย) ----------
# ตอนนี้คลิกซ้ายจะทำงานเฉพาะตอนยืนอยู่บนพื้นในสถานะ IDLE เท่านั้น (กันโจมตีระหว่างชาร์จ/ลอยกลางอากาศ/เด้งกำแพง/ตาย)
# ถ้าอยากให้โจมตีกลางอากาศได้ด้วย ให้เพิ่ม State.JUMPING, State.FALLING ในเงื่อนไขเช็ค Input.is_action_just_pressed("attack")
#
# ตอนโจมตี ตัวละครจะเข้า State.ATTACK ล็อกไม่ให้เดิน (velocity.x = 0) เป็นเวลา attack_duration วินาที
# ให้ตั้งเวลานี้ให้พอดีกับความยาวจริงของอนิเมชัน "attack" ใน SpriteFrames
# จบท่าแล้วจะเข้าเวลาพัก attack_cooldown ก่อนจะกดโจมตีซ้ำได้อีกครั้ง
#
# ระบบนี้ยังไม่ได้ต่อ hitbox ตรวจชนศัตรูจริง — จุดที่ควรเพิ่มคือใน _start_attack()
# แนะนำให้เพิ่ม Area2D ชื่อ เช่น "AttackHitbox" เป็นลูกของตัวละคร (วางตำแหน่งด้านหน้าตามทิศ facing)
# แล้วเปิด monitoring = true ตอนเริ่มโจมตี ปิดตอนจบ State.ATTACK จากนั้นเชื่อม signal
# area_entered/body_entered ของ hitbox นั้นเพื่อเรียก take_damage(attack_damage) กับศัตรูที่ชน
