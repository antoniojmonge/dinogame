extends CharacterBody3D

## Controlador estilo Sonic: el dino corre solo hacia adelante,
## el jugador gira a izquierda/derecha y salta.

@export var max_speed := 22.0
@export var acceleration := 25.0
@export var steering_speed := 2.4
@export var jump_velocity := 13.0
@export var gravity := 32.0

@onready var anim: AnimationPlayer = $Model/AnimationPlayer

const ANIM_IDLE := "Armature|TRex_Idle"
const ANIM_WALK := "Armature|TRex_Walk"
const ANIM_RUN := "Armature|TRex_Run"
const ANIM_JUMP := "Armature|TRex_Jump"

var speed := 0.0


func _ready() -> void:
	_setup_animations()


func _setup_animations() -> void:
	if anim == null:
		return
	for name in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if anim.has_animation(name):
			anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_play(ANIM_RUN, true)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	speed = move_toward(speed, max_speed, acceleration * delta)

	var turn := Input.get_axis("move_left", "move_right")
	rotate_y(-turn * steering_speed * delta)

	var forward := -transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed

	move_and_slide()

	_update_animation()

	if global_position.y < -20.0:
		get_tree().reload_current_scene()


func _update_animation() -> void:
	if anim == null:
		return
	if not is_on_floor():
		_play(ANIM_JUMP)
	else:
		_play(ANIM_RUN)
		anim.speed_scale = clampf(speed / max_speed, 0.7, 1.6)


func _play(name: String, force := false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if force or anim.current_animation != name:
		anim.play(name)
