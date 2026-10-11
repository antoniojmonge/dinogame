extends CharacterBody3D

## Controlador estilo Sonic: el dino corre solo hacia adelante,
## el jugador gira a izquierda/derecha y salta.

@export var max_speed := 22.0
@export var acceleration := 25.0
@export var steering_speed := 2.4
@export var jump_velocity := 13.0
@export var gravity := 32.0

var speed := 0.0


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

	if global_position.y < -20.0:
		get_tree().reload_current_scene()
